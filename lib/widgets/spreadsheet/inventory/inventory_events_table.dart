// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/factories/record_factory.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/repositories/utils/firestore_document_helpers.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/pagination_service.dart';
import 'package:seafoundry_app/utils/user_display_name.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_base.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_models.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_scroll_view.dart';
import 'package:seafoundry_app/widgets/spreadsheet/components/responsive_filter_section.dart';

/// Default event types for inventory events.
const Set<String> _defaultInventoryEventTypes = {
  'event_create',
  'event_update',
  'event_quantity_change',
  'event_split',
  'event_merge',
  'event_move_in',
  'event_move_out',
  'event_population_loss',
  'event_population_gain',
  'event_life_stage_transition',
  'event_physical_form_change',
};

/// Event types for outplanting events.
const Set<String> _outplantingEventTypes = {
  'outplant_event',
  'event_create',
};

/// Event label overrides for display.
const Map<String, String> _inventoryEventLabels = {
  'event_create': 'Created',
  'event_update': 'Updated',
  'event_quantity_change': 'Quantity Change',
  'event_split': 'Split',
  'event_merge': 'Merge',
  'event_move_in': 'Move In',
  'event_move_out': 'Move Out',
  'event_population_loss': 'Population Loss',
  'event_population_gain': 'Population Gain',
  'event_life_stage_transition': 'Life Stage Transition',
  'event_physical_form_change': 'Physical Form Change',
  'outplant_event': 'Outplant',
};

/// A parameterized events table that works for both inventory and outplanting events.
///
/// When [outplantingOnly] is true, the table filters to show only
/// outplanting-related event types. Otherwise it shows the default set
/// of inventory event types.
///
/// Uses [EventRepository] to fetch events and [PaginationService] for
/// client-side pagination via [SpreadsheetBase].
class InventoryEventsTable extends StatefulWidget {
  const InventoryEventsTable({
    super.key,
    this.outplantingOnly = false,
  });

  /// When true, filters events to show only outplanting-related types.
  final bool outplantingOnly;

  @override
  State<InventoryEventsTable> createState() => _InventoryEventsTableState();
}

class _InventoryEventsTableState extends State<InventoryEventsTable>
    with SafeProviderReadMixin {
  static const _eventFetchLimit = 250;
  static const _eventHydrationBatchSize = 20;

  bool _isLoading = true;
  double? _loadingProgress;
  String? _loadingStatus;
  String? _error;

  final List<_InventoryEventRow> _rows = [];
  List<_InventoryEventRow> _filteredRows = const [];
  final PaginationService<_InventoryEventRow> _paginationService =
      const PaginationService<_InventoryEventRow>();

  String? _selectedEventType;
  DateTimeRange? _selectedDateRange;

  final Map<String, String> _userNameCache = {};
  final Map<String, OrganismRecord?> _organismCache = {};

  Set<String> get _eventTypeFilter => widget.outplantingOnly
      ? _outplantingEventTypes
      : _defaultInventoryEventTypes;

  String get _title =>
      widget.outplantingOnly ? 'Outplanting Events' : 'Inventory Events';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEvents());
  }

  Future<void> _loadEvents() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _loadingProgress = null;
      _loadingStatus = 'Loading $_title...';
      _error = null;
    });

    final providerResult = safeReadProviders(() => (
          context.read<RecordRepository>(),
          context.read<OrganismRecordRepository>(),
          context.read<CurrentUser>().state,
        ));

    if (!providerResult.success) {
      if (!mounted) return;
      setState(() {
        _error = providerResult.errorMessage;
        _isLoading = false;
      });
      return;
    }

    final (recordRepository, organismRepository, currentUserState) =
        providerResult.value!;

    String? organizationId;
    if (currentUserState is CurrentUserLoaded) {
      organizationId = currentUserState.organization.id;
    }
    if (organizationId == null || organizationId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _error = 'Session expired. Please refresh the page.';
        _isLoading = false;
        _loadingProgress = null;
        _loadingStatus = null;
      });
      return;
    }

    try {
      if (!mounted) return;

      // Fetch events from Firestore, filtered by organization and ordered by
      // creation date descending. We apply event type filtering client-side
      // since Firestore whereIn has a 30-item limit.
      final query = recordRepository.db
          .collection(ModelType.event.collectionPath)
          .where('organizationId', isEqualTo: organizationId)
          .orderBy('createdAt', descending: true)
          .limit(_eventFetchLimit);

      if (!mounted) return;
      final snapshot = await query.get();
      final events = <Event>[];
      for (final doc in snapshot.docs) {
        try {
          final json = FirestoreDocumentHelpers.injectDocumentId(doc);
          events.add(RecordFactory.eventFromJson(json));
        } catch (error, stackTrace) {
          LoggingService.instance.error(
            'Failed to parse event document ${doc.id}',
            error,
            stackTrace,
          );
        }
      }

      LoggingService.instance.info(
        '$_title: Parsed ${events.length} events from Firestore',
      );

      // Filter to supported event types
      final candidates = <_InventoryEventCandidate>[];
      for (final event in events) {
        final eventTypeId = event.eventTypeId;
        if (eventTypeId.isEmpty) continue;
        if (!_eventTypeFilter.contains(eventTypeId)) continue;
        candidates.add(_InventoryEventCandidate(event, eventTypeId));
      }

      if (!mounted) return;
      setState(() {
        _loadingProgress = candidates.isEmpty ? null : 0;
        _loadingStatus = candidates.isEmpty
            ? 'No events to hydrate.'
            : 'Hydrating ${candidates.length} events...';
      });

      // Hydrate events in batches
      final rows = <_InventoryEventRow>[];
      var hydratedCount = 0;
      for (var i = 0; i < candidates.length; i += _eventHydrationBatchSize) {
        final batch =
            candidates.skip(i).take(_eventHydrationBatchSize).toList();
        final batchRows = await Future.wait(
          batch.map((candidate) async {
            try {
              return await _hydrateEvent(
                candidate.event,
                candidate.eventTypeId,
                recordRepository,
                organismRepository,
              );
            } catch (error, stackTrace) {
              LoggingService.instance.error(
                'Failed to hydrate event ${candidate.event.id}',
                error,
                stackTrace,
              );
              return null;
            }
          }),
        );

        rows.addAll(batchRows.whereType<_InventoryEventRow>());
        hydratedCount += batch.length;
        if (!mounted) return;
        if (candidates.isNotEmpty) {
          setState(() {
            _loadingProgress = hydratedCount / candidates.length;
            _loadingStatus =
                'Hydrating events $hydratedCount/${candidates.length}';
          });
        }
      }

      LoggingService.instance.info(
        '$_title: ${rows.length} events hydrated',
      );

      if (!mounted) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(rows);
        _applyFilters(updateState: false);
        _isLoading = false;
        _loadingProgress = null;
        _loadingStatus = null;
      });
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to load $_title',
        error,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load events: $error';
        _isLoading = false;
        _loadingProgress = null;
        _loadingStatus = null;
      });
    }
  }

  Future<_InventoryEventRow?> _hydrateEvent(
    Event event,
    String eventTypeId,
    RecordRepository recordRepository,
    OrganismRecordRepository organismRepository,
  ) async {
    if (!mounted) return null;

    final userName = await resolveUserDisplayName(
      recordRepository: recordRepository,
      userId: event.createdById,
      cache: _userNameCache,
    );

    // Resolve organism record for display
    OrganismRecord? organism;
    if (event.recordId.isNotEmpty) {
      organism = await _resolveOrganism(event.recordId, organismRepository);
    }

    final recordDisplay = organism?.recordName ?? event.recordId;
    final genetLocalId = organism?.localId;
    final siteName = organism?.siteId ?? '';

    // Build details string from event metadata
    final details = _buildEventDetails(event, eventTypeId, organism);

    final eventLabel = _inventoryEventLabels[eventTypeId] ??
        EventType.builtins[eventTypeId]?.name ??
        eventTypeId;

    return _InventoryEventRow(
      eventId: event.id,
      eventTypeId: eventTypeId,
      eventLabel: eventLabel,
      recordDisplay: recordDisplay,
      genetLocalId: genetLocalId ?? '',
      details: details,
      siteName: siteName,
      userName: userName,
      createdAt: event.createdAtDateTime,
    );
  }

  Future<OrganismRecord?> _resolveOrganism(
    String organismId,
    OrganismRecordRepository organismRepository,
  ) async {
    final id = organismId.trim();
    if (id.isEmpty) return null;
    if (_organismCache.containsKey(id)) {
      return _organismCache[id];
    }

    try {
      if (!mounted) return null;
      final organism = await organismRepository.getRecordForId(id);
      if (!mounted) return null;
      if (mounted) {
        _organismCache[id] = organism;
      }
      return organism;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to resolve organism $id',
        error,
        stackTrace,
      );
      if (mounted) {
        _organismCache[id] = null;
      }
      return null;
    }
  }

  String _buildEventDetails(
    Event event,
    String eventTypeId,
    OrganismRecord? organism,
  ) {
    final parts = <String>[];
    final metadata = event.metadata;

    if (metadata != null) {
      // Quantity change details
      final oldCount = metadata['oldCount'];
      final newCount = metadata['newCount'];
      if (oldCount != null && newCount != null) {
        parts.add('$oldCount -> $newCount');
      }

      // Life stage transition details
      final oldLifeStage = metadata['oldLifeStageId'];
      final newLifeStage = metadata['newLifeStageId'];
      if (oldLifeStage != null && newLifeStage != null) {
        parts.add('$oldLifeStage -> $newLifeStage');
      }

      // Notes
      final notes = metadata['notes'];
      if (notes is String && notes.isNotEmpty) {
        parts.add(notes);
      }
    }

    return parts.join(' | ');
  }

  void _applyFilters({bool updateState = true}) {
    Iterable<_InventoryEventRow> rows = _rows;

    if (_selectedEventType != null && _selectedEventType!.isNotEmpty) {
      rows = rows.where((row) => row.eventTypeId == _selectedEventType);
    }

    if (_selectedDateRange != null) {
      final start = _selectedDateRange!.start;
      final end = _selectedDateRange!.end
          .add(const Duration(hours: 23, minutes: 59, seconds: 59));
      rows = rows.where((row) {
        final createdAt = row.createdAt;
        if (createdAt == null) return false;
        return !createdAt.isBefore(start) && !createdAt.isAfter(end);
      });
    }

    final sorted = rows.toList()
      ..sort((a, b) {
        final aTime =
            a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        final bTime =
            b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        return bTime.compareTo(aTime);
      });

    if (updateState) {
      setState(() {
        _filteredRows = sorted;
      });
    } else {
      _filteredRows = sorted;
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedEventType = null;
      _selectedDateRange = null;
      _applyFilters(updateState: false);
    });
  }

  bool get _hasActiveFilters =>
      _selectedEventType != null || _selectedDateRange != null;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final progress = _loadingProgress;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (_loadingStatus != null) ...[
              const SizedBox(height: 12),
              Text(
                _loadingStatus!,
                textAlign: TextAlign.center,
              ),
            ],
            if (progress != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: 220,
                child: LinearProgressIndicator(value: progress),
              ),
            ],
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadEvents,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.outplantingOnly ? Icons.nature : Icons.event_note,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              'No $_title found',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final headerWidgets = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveFilterSection(
              label: 'Filters',
              initiallyExpanded: false,
              child: _buildToolbar(context),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ];

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: _filteredRows.isEmpty
          ? const Center(
              child: Text(
                'No events match the current filters.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : SpreadsheetBase<_InventoryEventRow>(
              key: ValueKey(
                '${_selectedEventType ?? 'all'}-${_selectedDateRange?.start}-${_selectedDateRange?.end}',
              ),
              columns: _columns,
              rowBuilder: _buildRow,
              pageLoader: _paginationService.buildListLoader(
                () => _filteredRows,
              ),
              sortField: 'timestamp',
              descending: true,
              header: Text('$_title - ${_filteredRows.length} records'),
            ),
    );

    return SpreadsheetScrollView(header: headerWidgets, body: body);
  }

  Widget _buildToolbar(BuildContext context) {
    final eventTypes = _rows.map((row) => row.eventTypeId).toSet().toList()
      ..sort((a, b) => _eventLabelFor(a).compareTo(_eventLabelFor(b)));

    final dateRangeLabel = _selectedDateRange == null
        ? 'Date Range'
        : '${DateFormat.yMMMd().format(_selectedDateRange!.start)} - '
            '${DateFormat.yMMMd().format(_selectedDateRange!.end)}';

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String?>(
            initialValue: _selectedEventType,
            decoration: const InputDecoration(
              labelText: 'Event Type',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All Event Types'),
              ),
              ...eventTypes.map(
                (eventTypeId) => DropdownMenuItem<String?>(
                  value: eventTypeId,
                  child: Text(_eventLabelFor(eventTypeId)),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedEventType = value;
                _applyFilters(updateState: false);
              });
            },
          ),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2015),
              lastDate: DateTime.now().add(const Duration(days: 1)),
              initialDateRange:
                  _selectedDateRange ??
                  DateTimeRange(
                    start: DateTime.now().subtract(const Duration(days: 30)),
                    end: DateTime.now(),
                  ),
            );
            if (picked != null) {
              setState(() {
                _selectedDateRange = picked;
                _applyFilters(updateState: false);
              });
            }
          },
          icon: const Icon(Icons.date_range),
          label: Text(dateRangeLabel),
        ),
        if (_selectedDateRange != null)
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedDateRange = null;
                _applyFilters(updateState: false);
              });
            },
            icon: const Icon(Icons.clear),
            label: const Text('Clear Dates'),
          ),
        FilledButton.icon(
          onPressed: _loadEvents,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
        if (_hasActiveFilters)
          TextButton(
            onPressed: _clearFilters,
            child: const Text('Reset Filters'),
          ),
      ],
    );
  }

  static String _eventLabelFor(String eventTypeId) {
    return _inventoryEventLabels[eventTypeId] ??
        EventType.builtins[eventTypeId]?.name ??
        eventTypeId;
  }

  static final List<SpreadsheetColumn> _columns = [
    const SpreadsheetColumn(
      key: 'timestamp',
      title: 'Date',
      width: 120,
      type: SpreadsheetColumnType.date,
    ),
    const SpreadsheetColumn(
      key: 'eventType',
      title: 'Event Type',
      width: 150,
    ),
    const SpreadsheetColumn(
      key: 'record',
      title: 'Record',
      width: 150,
    ),
    const SpreadsheetColumn(
      key: 'genet',
      title: 'Genet',
      width: 130,
    ),
    const SpreadsheetColumn(
      key: 'details',
      title: 'Details',
      width: 250,
    ),
    const SpreadsheetColumn(
      key: 'site',
      title: 'Site',
      width: 130,
    ),
    const SpreadsheetColumn(
      key: 'user',
      title: 'User',
      width: 140,
    ),
  ];

  SpreadsheetRow _buildRow(_InventoryEventRow row) {
    final dateStr = row.createdAt != null
        ? DateFormat.yMMMd().format(row.createdAt!)
        : '';
    return SpreadsheetRow(
      cells: {
        'timestamp': SpreadsheetCell.text(dateStr),
        'eventType': SpreadsheetCell.text(row.eventLabel),
        'record': SpreadsheetCell.text(row.recordDisplay),
        'genet': SpreadsheetCell.text(row.genetLocalId),
        'details': SpreadsheetCell.text(row.details),
        'site': SpreadsheetCell.text(row.siteName),
        'user': SpreadsheetCell.text(row.userName),
      },
    );
  }
}

class _InventoryEventCandidate {
  const _InventoryEventCandidate(this.event, this.eventTypeId);

  final Event event;
  final String eventTypeId;
}

/// A hydrated row representing an inventory event for spreadsheet display.
class _InventoryEventRow {
  const _InventoryEventRow({
    required this.eventId,
    required this.eventTypeId,
    required this.eventLabel,
    required this.recordDisplay,
    required this.genetLocalId,
    required this.details,
    required this.siteName,
    required this.userName,
    required this.createdAt,
  });

  final String eventId;
  final String eventTypeId;
  final String eventLabel;
  final String recordDisplay;
  final String genetLocalId;
  final String details;
  final String siteName;
  final String userName;
  final DateTime? createdAt;
}
