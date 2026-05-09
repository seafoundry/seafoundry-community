// @tier: community
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/events/create_event.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/genet_modification_event.dart';
import 'package:seafoundry_app/models/events/inventory_event.dart';
import 'package:seafoundry_app/models/events/transfer_event.dart';
import 'package:seafoundry_app/models/events/update_event.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/provenance_life_stage_selection.dart';
import 'package:seafoundry_app/models/factories/record_factory.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/transfer_status.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/loan_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/repositories/utils/firestore_document_helpers.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/pagination_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/utils/date_range_utils.dart';
import 'package:seafoundry_app/utils/user_display_name.dart';
import 'package:seafoundry_app/utils/provenance_selection_utils.dart';
import 'package:seafoundry_app/widgets/common/quick_date_range_chips.dart';
import '../../common/organism_reference_links.dart';
import 'package:seafoundry_app/widgets/spreadsheet/components/alias_badge.dart';
import 'package:seafoundry_app/widgets/spreadsheet/components/responsive_filter_section.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_base.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_models.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_scroll_view.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';

const Set<String> _supportedEventTypeIds = {
  'event_create',
  'event_update',
  LoanEventType.loanId,
  LoanEventType.legacyTransferId,
  'event_genet_modification',
};

const Map<String, String> _eventLabelOverrides = {
  'event_create': 'Created',
  'event_update': 'Updated',
  'event_loan': 'Transfer',
  'event_transfer': 'Transfer',
  'event_genet_modification': 'Record Modified',
};

const Map<String, String> _genetFieldLabels = {
  'name': 'Local ID',
  'provenanceTypeId': 'Provenance Type',
  'speciesId': 'Species',
  'provenanceId': 'Provenance ID',
  'clonalId': 'Clonal ID',
  'accessionNumber': 'Accession #',
  'notes': 'Notes',
  'parentGameteIds': 'Parent Gametes',
  'parentCohortId': 'Parent Cohort',
  'donorGenotypeId': 'Donor Genotype',
  'metadata.provenanceTypeId': 'Provenance Type',
  'metadata.lifeStageId': 'Life Stage',
};

const Map<String, String> _coralFieldLabels = {
  'name': 'Record Name',
  'tagId': 'Record Name',
  'quantity': 'Quantity',
  'physicalForm.formId': 'Physical Form',
  'genetId': 'Genet ID',
  'siteId': 'Site',
  'groupId': 'Structure',
  'notes': 'Notes',
  'metadata.lifeStageId': 'Life Stage',
  'metadata.physicalFormId': 'Physical Form',
};

class _GeneticsEventCandidate {
  const _GeneticsEventCandidate(this.event, this.eventTypeId);

  final Event event;
  final String eventTypeId;
}

class GeneticsEventsTable extends StatefulWidget {
  const GeneticsEventsTable({super.key, this.leadingHeader = const <Widget>[]});

  final List<Widget> leadingHeader;

  @override
  State<GeneticsEventsTable> createState() => _GeneticsEventsTableState();
}

class _GeneticsEventsTableState extends State<GeneticsEventsTable>
    with SafeProviderReadMixin {
  static const _eventFetchLimit = 250;
  static const _eventHydrationBatchSize = 20;

  bool _isLoading = true;
  double? _loadingProgress;
  String? _loadingStatus;
  String? _error;

  final List<_GeneticsEventRow> _rows = [];
  List<_GeneticsEventRow> _filteredRows = const [];
  final PaginationService<_GeneticsEventRow> _paginationService =
      const PaginationService<_GeneticsEventRow>();

  String? _selectedEventType;
  ModelType? _selectedRecordType;
  DateTimeRange? _selectedDateRange;
  String _searchTerm = '';

  late final TextEditingController _searchController;

  final Map<String, String> _userNameCache = {};
  final Map<String, Genet?> _genetCache = {};
  final Map<String, OrganismRecord?> _organismCache = {};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEvents());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _loadingProgress = null;
      _loadingStatus = 'Loading genetics events...';
      _error = null;
    });

    // Cache provider references before async operations
    final providerResult = safeReadProviders(() => (
      context.read<RecordRepository>(),
      context.read<GenetRepository>(),
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

    final (recordRepository, genetRepository, organismRepository, currentUserState) =
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

      // IMPORTANT: Filter by organizationId to satisfy Firestore security rules.
      // Without this filter, Firestore will deny access because the rules require
      // resource.data.organizationId to match the user's organizationId.
      if (!mounted) return;
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
          // Inject doc.id since Firestore data() doesn't include document ID
          final json = FirestoreDocumentHelpers.injectDocumentId(doc);
          events.add(RecordFactory.eventFromJson(json));
        } catch (error, stackTrace) {
          LoggingService.instance.error('Event document data: ${doc.data()}');
          LoggingService.instance.error(
            'Failed to parse event document ${doc.id}',
            error,
            stackTrace,
          );
        }
      }

      LoggingService.instance.info(
        'GeneticsEventsTable: Parsed ${events.length} events from Firestore',
      );

      final rows = <_GeneticsEventRow>[];
      final candidates = <_GeneticsEventCandidate>[];
      var skippedUnsupportedType = 0;
      var skippedIrrelevantRecord = 0;
      var skippedNullRow = 0;
      for (final event in events) {
        final eventTypeId = _sanitizeEventTypeId(event.eventTypeId);
        if (eventTypeId == null) {
          LoggingService.instance.warning(
            'Skipping genetics event with missing type: ${event.id}',
          );
          continue;
        }
        if (!_isSupportedEventType(eventTypeId)) {
          skippedUnsupportedType++;
          continue;
        }
        if (!_isRelevantRecordType(event.recordModelType)) {
          skippedIrrelevantRecord++;
          continue;
        }
        candidates.add(_GeneticsEventCandidate(event, eventTypeId));
      }

      if (!mounted) return;
      setState(() {
        _loadingProgress = candidates.isEmpty ? null : 0;
        _loadingStatus = candidates.isEmpty
            ? 'No events to hydrate.'
            : 'Hydrating ${candidates.length} events...';
      });

      var hydratedCount = 0;
      for (var i = 0; i < candidates.length; i += _eventHydrationBatchSize) {
        final batch = candidates.skip(i).take(_eventHydrationBatchSize).toList();
        final batchRows = await Future.wait(
          batch.map((candidate) async {
            try {
              final row = await _GeneticsEventRow.fromEvent(
                event: candidate.event,
                eventTypeId: candidate.eventTypeId,
                resolveUserName: (userId) =>
                    _resolveUserName(userId, recordRepository),
                resolveGenet: (genetId) => _resolveGenet(genetId, genetRepository),
                resolveOrganism: (organismId) =>
                    _resolveOrganism(organismId, organismRepository),
              );
              if (row == null) {
                skippedNullRow++;
                LoggingService.instance.warning(
                  'GeneticsEventsTable: null row for event ${candidate.event.id} '
                  '(type: ${candidate.eventTypeId}, record: ${candidate.event.recordModelType}, '
                  'runtime: ${candidate.event.runtimeType})',
                );
                return null;
              }
              return row;
            } catch (error, stackTrace) {
              LoggingService.instance.error(
                'Failed to parse genetics event ${candidate.event.id}',
                error,
                stackTrace,
              );
              return null;
            }
          }),
        );

        rows.addAll(batchRows.whereType<_GeneticsEventRow>());
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
        'GeneticsEventsTable: ${rows.length} events included, '
        '$skippedUnsupportedType unsupported type, '
        '$skippedIrrelevantRecord irrelevant record, '
        '$skippedNullRow null rows',
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
        'Failed to load genetics events',
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

  Future<String> _resolveUserName(
    String userId,
    RecordRepository recordRepository,
  ) async {
    return resolveUserDisplayName(
      recordRepository: recordRepository,
      userId: userId,
      cache: _userNameCache,
    );
  }

  Future<Genet?> _resolveGenet(String? genetId, GenetRepository genetRepository) async {
    final id = genetId?.trim();
    if (id == null || id.isEmpty) return null;
    if (_genetCache.containsKey(id)) {
      return _genetCache[id];
    }

    try {
      if (!mounted) return null;
      final genet = await genetRepository.getRecordForId(id);
      if (!mounted) return null;
      if (mounted) {
        _genetCache[id] = genet;
      }
      return genet;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to resolve genet $id',
        error,
        stackTrace,
      );
      if (mounted) {
        _genetCache[id] = null;
      }
      return null;
    }
  }

  Future<OrganismRecord?> _resolveOrganism(String? organismId, OrganismRecordRepository organismRepository) async {
    final id = organismId?.trim();
    if (id == null || id.isEmpty) return null;
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

  void _applyFilters({bool updateState = true}) {
    Iterable<_GeneticsEventRow> rows = _rows;

    if (_selectedEventType != null && _selectedEventType!.isNotEmpty) {
      rows = rows.where((row) => row.eventTypeId == _selectedEventType);
    }

    if (_selectedRecordType != null) {
      rows = rows.where((row) => row.recordModelType == _selectedRecordType);
    }

    if (_selectedDateRange != null) {
      final start = DateRangePresets.startOfDay(_selectedDateRange!.start);
      final end = DateRangePresets.endOfDay(_selectedDateRange!.end);
      rows = rows.where((row) {
        final createdAt = row.createdAt;
        if (createdAt == null) return false;
        return !createdAt.isBefore(start) && !createdAt.isAfter(end);
      });
    }

    if (_searchTerm.isNotEmpty) {
      final needle = _searchTerm.toLowerCase();
      rows = rows.where((row) {
        final fields = [
          row.recordDisplay,
          row.description,
          row.speciesName ?? '',
          row.provenanceTypeLabel ?? '',
          row.lifeStageLabel ?? '',
          row.userName ?? '',
          ...row.aliases.map((alias) => alias.label ?? alias.value),
          ...row.aliases.map((alias) => alias.sourceSystem),
        ];
        return fields.any((value) => value.toLowerCase().contains(needle));
      });
    }

    final sorted = rows
        .sorted((a, b) {
          final aTime =
              a.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
          final bTime =
              b.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
          return bTime.compareTo(aTime);
        })
        .toList(growable: false);

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
      _selectedRecordType = null;
      _selectedDateRange = null;
      _searchTerm = '';
      _searchController.text = '';
      _applyFilters(updateState: false);
    });
  }

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
      return _buildError();
    }

    if (_rows.isEmpty) {
      return _buildNoEventsState();
    }

    final headerWidgets = <Widget>[
      ...widget.leadingHeader,
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
          ? _buildNoMatchesState()
          : SpreadsheetBase<_GeneticsEventRow>(
              key: ValueKey(
                '${_selectedEventType ?? 'all'}-${_selectedRecordType?.name ?? 'all'}-${_selectedDateRange?.start}-${_selectedDateRange?.end}-$_searchTerm',
              ),
              columns: _columns,
              rowBuilder: _buildRow,
              pageLoader: _paginationService.buildListLoader(
                () => _filteredRows,
              ),
              sortField: 'timestamp',
              descending: true,
              header: Text('Genetics Events • ${_filteredRows.length} records'),
            ),
    );

    return SpreadsheetScrollView(header: headerWidgets, body: body);
  }

  Widget _buildToolbar(BuildContext context) {
    final eventTypes = _rows.map((row) => row.eventTypeId).toSet().toList()
      ..sort((a, b) => _eventLabelFor(a).compareTo(_eventLabelFor(b)));

    final recordTypes = _rows.map((row) => row.recordModelType).toSet().toList()
      ..sort((a, b) => _recordTypeLabel(a).compareTo(_recordTypeLabel(b)));

    final dateRangeLabel = _selectedDateRange == null
        ? 'Date Range'
        : '${DateFormat.yMMMd().format(_selectedDateRange!.start)} – '
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
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<ModelType?>(
            initialValue: _selectedRecordType,
            decoration: const InputDecoration(
              labelText: 'Record Type',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem<ModelType?>(
                value: null,
                child: Text('All Record Types'),
              ),
              ...recordTypes.map(
                (recordType) => DropdownMenuItem<ModelType?>(
                  value: recordType,
                  child: Text(_recordTypeLabel(recordType)),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedRecordType = value;
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
        QuickDateRangeChips(
          selectedRange: _selectedDateRange,
          onRangeSelected: (range) {
            setState(() {
              _selectedDateRange = range;
              _applyFilters(updateState: false);
            });
          },
        ),
        SizedBox(
          width: 220,
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search',
              prefixIcon: Icon(Icons.search, size: 18),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _searchTerm = value.trim();
                _applyFilters(updateState: false);
              });
            },
          ),
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

  bool get _hasActiveFilters =>
      _selectedEventType != null ||
      _selectedRecordType != null ||
      _selectedDateRange != null ||
      _searchTerm.isNotEmpty;

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadEvents,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoEventsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.event_note, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No genetics events recorded yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Create corals, genets, or transfers and they will appear here.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMatchesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list, size: 64, color: Colors.blueGrey),
            const SizedBox(height: 12),
            const Text(
              'No events match the current filters',
              style: TextStyle(fontSize: 18),
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Reset Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const List<SpreadsheetColumn> _columns = [
  SpreadsheetColumn(key: 'timestamp', title: 'Timestamp', width: 170),
  SpreadsheetColumn(key: 'event', title: 'Event', width: 180),
  SpreadsheetColumn(key: 'record', title: 'Record', width: 220),
  SpreadsheetColumn(key: 'details', title: 'Details', width: 320),
  SpreadsheetColumn(key: 'aliases', title: 'Aliases', width: 220),
  SpreadsheetColumn(key: 'species', title: 'Species', width: 180),
  SpreadsheetColumn(key: 'provenanceType', title: 'Provenance Type', width: 180),
  SpreadsheetColumn(key: 'lifeStage', title: 'Life Stage', width: 150),
  SpreadsheetColumn(key: 'user', title: 'User', width: 160),
];

SpreadsheetRow _buildRow(_GeneticsEventRow row) {
  final timestamp = row.createdAt != null
      ? DateFormat('yyyy-MM-dd HH:mm').format(row.createdAt!.toLocal())
      : '';
  final recordTypeLabel = _recordTypeLabel(row.recordModelType);
  final eventCell = recordTypeLabel.isEmpty
      ? row.eventLabel
      : '${row.eventLabel} • $recordTypeLabel';
  final aliasCell = SpreadsheetCell(
    child: SpreadsheetAliasBadges(aliases: row.aliases),
  );

  return SpreadsheetRow(
    raw: row.toJson(),
    key: ValueKey(row.eventId),
    cells: {
      'timestamp': SpreadsheetCell.text(timestamp),
      'event': SpreadsheetCell.text(eventCell),
      'record': SpreadsheetCell(
        child: row.recordLink ??
            Text(
              row.recordDisplay,
              overflow: TextOverflow.ellipsis,
            ),
      ),
      'details': SpreadsheetCell.text(row.description),
      'aliases': aliasCell,
      'species': SpreadsheetCell.text(row.speciesName ?? ''),
      'provenanceType':
          SpreadsheetCell.text(row.provenanceTypeLabel ?? ''),
      'lifeStage': SpreadsheetCell.text(row.lifeStageLabel ?? ''),
      'user': SpreadsheetCell.text(row.userName ?? ''),
    },
  );
}

class _GeneticsEventRow {
  _GeneticsEventRow({
    required this.eventId,
    required this.eventTypeId,
    required this.eventLabel,
    required this.recordModelType,
    required this.recordId,
    required this.recordDisplay,
    required this.recordLink,
    required this.createdAt,
    required this.userName,
    required this.description,
    required this.speciesName,
    required this.provenanceTypeLabel,
    required this.lifeStageLabel,
    required this.aliases,
  });

  final String eventId;
  final String eventTypeId;
  final String eventLabel;
  final ModelType recordModelType;
  final String recordId;
  final String recordDisplay;
  final Widget? recordLink;
  final DateTime? createdAt;
  final String? userName;
  final String description;
  final String? speciesName;
  final String? provenanceTypeLabel;
  final String? lifeStageLabel;
  final List<OrganismAlias> aliases;

  static Future<_GeneticsEventRow?> fromEvent({
    required Event event,
    required String eventTypeId,
    required Future<String> Function(String) resolveUserName,
    required Future<Genet?> Function(String?) resolveGenet,
    required Future<OrganismRecord?> Function(String?) resolveOrganism,
  }) async {
    final createdAt = DateTime.tryParse(event.createdAt);
    final userName = await resolveUserName(event.createdById);

    String recordDisplay = event.recordId;
    Widget? recordLink;
    String? speciesName;
    String? provenanceTypeLabel;
    String? lifeStageLabel;
    String? provenanceTypeId;
    String? fallbackLifeStageId;
    String description = '';
    List<OrganismAlias> aliases = const <OrganismAlias>[];

    void applySelection(ProvenanceLifeStageSelection? selection) {
      if (selection == null) return;
      provenanceTypeLabel = selection.provenanceType.displayName;
      lifeStageLabel = selection.lifeStage.displayName;
    }

    if (event is InventoryEvent) {
      final snapshot = event.snapshot;
      if (snapshot is Genet) {
        recordDisplay = _asNonEmptyString(snapshot.name) ?? event.recordId;
        recordLink = GenetIdLink(
          localGenetId: snapshot.localGenetId ?? snapshot.name,
          genetId: snapshot.id,
          showUnderline: true,
        );
        speciesName = _speciesLabel(snapshot.speciesId);
        provenanceTypeId = snapshot.provenanceTypeId;
        applySelection(ProvenanceLifeStageSelection.fromGenet(snapshot));
        fallbackLifeStageId = snapshot.provenance?['lifeStageId']?.toString();
        description = _describeGenetInventoryEvent(event, snapshot);
        aliases = snapshot.aliasEntries;
      } else if (snapshot is OrganismRecord) {
        recordDisplay = _asNonEmptyString(snapshot.name) ?? event.recordId;
        recordLink = OrganismReferenceLinks(
          tagId: snapshot.tagId,
          localGenetId: snapshot.localGenetId,
          urlPath: snapshot.urlPath,
          genetId: snapshot.genetId,
          showUnderline: true,
        );
        speciesName = _speciesLabel(snapshot.speciesId);
        fallbackLifeStageId = snapshot.lifeStage.stage.id;
        final genetId = GenetIdResolver.resolve(snapshot);
        final genet = await resolveGenet(genetId);
        provenanceTypeId = genet?.provenanceTypeId;
        applySelection(buildProvenanceSelection(organism: snapshot, provenance: genet));
        description = _describeOrganismInventoryEvent(event, snapshot);
        aliases = genet?.aliasEntries ?? const <OrganismAlias>[];
      } else {
        LoggingService.instance.warning(
          'GeneticsEventsTable: InventoryEvent ${event.id} has unsupported snapshot type: '
          '${snapshot.runtimeType} (modelType: ${snapshot.modelType})',
        );
        return null;
      }
    } else if (event is GenetModificationEvent) {
      final genet = await resolveGenet(event.recordId);
      recordDisplay = genet?.name ?? event.recordId;
      if (genet != null) {
        recordLink = GenetIdLink(
          localGenetId: genet.localGenetId ?? genet.name,
          genetId: genet.id,
          showUnderline: true,
        );
      }
      speciesName = _speciesLabel(genet?.speciesId);
      provenanceTypeId = genet?.provenanceTypeId;
      applySelection(ProvenanceLifeStageSelection.fromGenet(genet));
      description = _formatGenetModificationDescription(event);
      aliases = genet?.aliasEntries ?? const <OrganismAlias>[];
    } else if (event is UpdateEvent) {
      OrganismRecord? resolvedOrganism;
      if (event.recordModelType == ModelType.genet) {
        final genet = await resolveGenet(event.recordId);
        recordDisplay = genet?.name ?? event.recordId;
        if (genet != null) {
          recordLink = GenetIdLink(
            localGenetId: genet.localGenetId ?? genet.name,
            genetId: genet.id,
            showUnderline: true,
          );
        }
        speciesName = _speciesLabel(genet?.speciesId);
        provenanceTypeId = genet?.provenanceTypeId;
        applySelection(ProvenanceLifeStageSelection.fromGenet(genet));
        aliases = genet?.aliasEntries ?? const <OrganismAlias>[];
      } else if (
          event.recordModelType == ModelType.organismRecord) {
        // Handle organism record types
        final organism = await resolveOrganism(event.recordId);
        resolvedOrganism = organism;
        recordDisplay = organism != null
            ? formatOrganismReferenceLabel(
                localGenetId: organism.localGenetId,
                tagId: organism.tagId,
                fallback: organism.name,
              )
            : event.recordId;
        if (organism != null) {
          recordLink = OrganismReferenceLinks(
            tagId: organism.tagId,
            localGenetId: organism.localGenetId,
            urlPath: organism.urlPath,
            genetId: organism.genetId,
            showUnderline: true,
          );
        }
        speciesName = _speciesLabel(organism?.speciesId);
        fallbackLifeStageId = organism?.lifeStage.stage.id ?? fallbackLifeStageId;
        if (organism != null) {
          final genetId = GenetIdResolver.resolve(organism);
          final genet = await resolveGenet(genetId);
          provenanceTypeId = genet?.provenanceTypeId ?? provenanceTypeId;
          applySelection(buildProvenanceSelection(organism: organism, provenance: genet));
          if (genet != null) {
            aliases = genet.aliasEntries;
          }
        }
      } else {
        return null;
      }
      description = _formatUpdateDescription(event, event.recordModelType, organism: resolvedOrganism);
    } else if (event is TransferEvent) {
      final manifestGenet =
          event.manifest?['genet'] as Map<String, dynamic>? ?? const {};
      final manifestName =
          _asNonEmptyString(manifestGenet['name']) ??
          _asNonEmptyString(manifestGenet['localGenetId']);
      recordDisplay = manifestName ?? event.genetId ?? event.recordId;

      final manifestSpeciesId = _asNonEmptyString(manifestGenet['speciesId']);
      if (manifestSpeciesId != null) {
        speciesName = _speciesLabel(manifestSpeciesId);
      }

      final manifestProvenanceTypeId =
          _asNonEmptyString(manifestGenet['provenanceTypeId']) ??
          _asNonEmptyString((manifestGenet['provenanceType'] as Map?)?['id']);
      if (manifestProvenanceTypeId != null) {
        provenanceTypeId = manifestProvenanceTypeId;
      }
      final manifestLifeStageId =
          _asNonEmptyString(manifestGenet['lifeStageId']) ??
          _asNonEmptyString((manifestGenet['lifeStage'] as Map?)?['id']);
      fallbackLifeStageId ??= manifestLifeStageId;

      applySelection(
        buildTransferProvenanceSelection(
          transfer: event,
          provenance: await resolveGenet(event.genetId),
        ),
      );

      description = _formatTransferDescription(event);
      aliases = _aliasesFromRaw(manifestGenet['aliases']);
    } else {
      return null;
    }

    provenanceTypeLabel ??=
        _provenanceLabelFromTypeId(provenanceTypeId);
    lifeStageLabel ??= _lifeStageLabelFromId(fallbackLifeStageId);

    return _GeneticsEventRow(
      eventId: event.id,
      eventTypeId: eventTypeId,
      eventLabel: _geneticsAwareEventLabel(eventTypeId, provenanceTypeLabel),
      recordModelType: event.recordModelType,
      recordId: event.recordId,
      recordDisplay: recordDisplay,
      recordLink: recordLink,
      createdAt: createdAt,
      userName: userName,
      description: description,
      speciesName: speciesName,
      provenanceTypeLabel: provenanceTypeLabel,
      lifeStageLabel: lifeStageLabel,
      aliases: aliases,
    );
  }

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'eventTypeId': eventTypeId,
    'eventLabel': eventLabel,
    'recordType': recordModelType.name,
    'recordId': recordId,
    'recordDisplay': recordDisplay,
    'createdAt': createdAt?.toIso8601String(),
    'userName': userName,
    'description': description,
    'speciesName': speciesName,
    'provenanceType': provenanceTypeLabel,
    'lifeStage': lifeStageLabel,
    'aliasLabels': aliases.map((alias) => alias.label ?? alias.value).toList(),
  };
}

String _describeGenetInventoryEvent(InventoryEvent event, Genet genet) {
  if (event is CreateEvent) {
    final details = <String>[_eventRecordLabel('Local ID', genet.name)];
    final selection = ProvenanceLifeStageSelection.fromGenet(genet);
    details.add(selection.provenanceType.displayName);
    details.add(selection.lifeStage.displayName);
    if (_asNonEmptyString(genet.provenanceId) != null) {
      details.add(genet.provenanceId);
    }
    return 'Genet created • ${details.join(' • ')}';
  }
  return 'Genet snapshot captured';
}

String _describeOrganismInventoryEvent(InventoryEvent event, OrganismRecord organism) {
  if (event is CreateEvent) {
    final details = <String>[
      _eventRecordLabel('Record Name', organism.name),
      'Qty ${organism.measurement.value.round()}',
    ];
    final lifeStageLabel = organism.lifeStage.stage.displayName;
    final physicalFormLabel = _physicalFormLabel(organism.physicalForm?.formId);
    details.add(lifeStageLabel);
    if (physicalFormLabel != null) {
      details.add(physicalFormLabel);
    }
    return 'Organism created • ${details.join(' • ')}';
  }
  return 'Organism snapshot captured';
}

String _eventRecordLabel(String label, String value) {
  final trimmed = value.trim();
  return '$label ${trimmed.isEmpty ? '—' : trimmed}';
}

List<OrganismAlias> _aliasesFromRaw(dynamic raw) {
  if (raw == null) return const <OrganismAlias>[];
  if (raw is Iterable) return OrganismAlias.listFromJson(raw);
  return OrganismAlias.listFromJson([raw]);
}

String _formatTransferDescription(TransferEvent event) {
  final statusLabel = _statusLabel(event.status);
  final parts = <String>['Quantity ${event.quantity}'];
  final fromOrg = _asNonEmptyString(event.fromOrganizationId);
  if (fromOrg != null) {
    parts.add('From $fromOrg');
  }
  final toOrg = _asNonEmptyString(event.toOrganizationId);
  if (toOrg != null) {
    parts.add('To $toOrg');
  }
  final comment = _asNonEmptyString(event.comment);
  if (comment != null) {
    parts.add(comment);
  }
  return 'Transfer $statusLabel • ${parts.join(' • ')}';
}

String _formatUpdateDescription(
  UpdateEvent event,
  ModelType recordType, {
  OrganismRecord? organism,
}) {
  final prefix = recordType == ModelType.genet
      ? 'Genet updated'
      : 'Organism updated';

  // Check if this update includes provenance type information (genetics events)
  // First check the fieldUpdates for various possible field paths, then fall back to the resolved organism
  String? provenanceTypeId = event.fieldUpdates['provenanceType']?.toString() ??
      event.fieldUpdates['provenanceTypeId']?.toString() ??
      event.fieldUpdates['metadata.provenanceTypeId']?.toString();

  if (provenanceTypeId == null && organism?.provenanceType != null) {
    provenanceTypeId = organism!.provenanceType!.id;
  }
  final provenanceTypeLabel = _provenanceTypeLabelFromId(provenanceTypeId);

  if (event.fieldUpdates.isEmpty) {
    // If no field updates but we have organism with provenance type, show that
    if (provenanceTypeLabel != null && organism != null) {
      final details = <String>[provenanceTypeLabel];

      final quantity = organism.measurement.value.round();
      if (quantity > 0) {
        details.add('Qty $quantity');
      }

      final lifeStageLabel = organism.lifeStage.stage.displayName;
      if (lifeStageLabel.isNotEmpty) {
        details.add(lifeStageLabel);
      }

      final physicalFormLabel = _physicalFormLabel(
        organism.physicalForm?.formId ??
            organism.metadata?['physicalFormId']?.toString(),
      );
      if (physicalFormLabel != null) {
        details.add(physicalFormLabel);
      }

      return details.join(' • ');
    }

    if (_asNonEmptyString(event.notes) != null) {
      return '$prefix • Notes: ${event.notes!.trim()}';
    }
    return prefix;
  }

  final updates = <String>[];

  // For genetics events, highlight provenance type first
  if (provenanceTypeLabel != null) {
    updates.add(provenanceTypeLabel);
  }

  // Extract quantity from field updates or organism
  String? quantityStr;
  if (event.fieldUpdates.containsKey('quantity')) {
    quantityStr = event.fieldUpdates['quantity']?.toString();
  } else if (event.fieldUpdates.containsKey('measurement')) {
    quantityStr = event.fieldUpdates['measurement']?.toString();
  } else if (organism != null) {
    quantityStr = organism.measurement.value.round().toString();
  }

  // Extract life stage from field updates or organism
  String? lifeStageLabel;
  if (event.fieldUpdates.containsKey('lifeStageId')) {
    lifeStageLabel = _lifeStageLabelFromId(event.fieldUpdates['lifeStageId']?.toString());
  } else if (event.fieldUpdates.containsKey('metadata.lifeStageId')) {
    lifeStageLabel = _lifeStageLabelFromId(event.fieldUpdates['metadata.lifeStageId']?.toString());
  } else if (organism != null) {
    lifeStageLabel = organism.lifeStage.stage.displayName;
  }

  event.fieldUpdates.forEach((field, value) {
    // Skip fields we've already processed
    if (field == 'provenanceType' || field == 'provenanceTypeId' || field == 'metadata.provenanceTypeId') return;
    if (field == 'quantity' || field == 'measurement') return;
    if (field == 'lifeStageId' || field == 'metadata.lifeStageId') return;

    final label = _fieldLabel(recordType, field);
    if (label == null) return;
    final display = _formatFieldValue(field, value);
    if (display.isEmpty) return;

    // For genetics events, simplify the display
    if (provenanceTypeLabel != null) {
      // Just show the value for key fields
      if (field == 'physicalForm.formId' || field == 'metadata.physicalFormId') {
        updates.add(display);
      } else {
        updates.add('$label → $display');
      }
    } else {
      updates.add('$label → $display');
    }
  });

  // Add quantity and life stage to updates for genetics events
  if (provenanceTypeLabel != null) {
    if (quantityStr != null && quantityStr.isNotEmpty) {
      final qty = double.tryParse(quantityStr)?.round();
      if (qty != null && qty > 0) {
        updates.insert(1, 'Qty $qty'); // Insert after provenance type
      }
    }

    if (lifeStageLabel != null && lifeStageLabel.isNotEmpty) {
      updates.add(lifeStageLabel);
    }
  }

  if (_asNonEmptyString(event.notes) != null) {
    updates.add('Notes: ${event.notes!.trim()}');
  }

  if (updates.isEmpty) {
    return prefix;
  }

  final updateTypeLabel = _formatUpdateType(event.updateType);
  final suffix = updates.join(' • ');

  // For genetics events, use cleaner format without redundant prefix
  if (provenanceTypeLabel != null) {
    return suffix;
  }

  return '$prefix${updateTypeLabel != null ? ' • $updateTypeLabel' : ''}: $suffix';
}

String _formatGenetModificationDescription(GenetModificationEvent event) {
  if (event.changes.isEmpty) {
    return 'Genet details updated';
  }

  final details = <String>[];

  event.changes.forEach((field, rawChange) {
    final label = _genetFieldLabels[field] ?? field;
    if (rawChange is Map) {
      if (field == 'provenance') {
        details.add('Provenance updated');
        return;
      }
      final before = _stringifyChangeValue(rawChange['before']);
      final after = _stringifyChangeValue(rawChange['after']);
      if (before == after) {
        details.add('$label updated');
      } else {
        details.add('$label: $before → $after');
      }
    } else {
      details.add('$label updated');
    }
  });

  if (details.isEmpty) {
    return 'Genet details updated';
  }

  if (details.length > 3) {
    final preview = details.take(3).join(' • ');
    return 'Genet updated • $preview • +${details.length - 3} more';
  }

  return 'Genet updated • ${details.join(' • ')}';
}

String _stringifyChangeValue(dynamic value) {
  if (value == null) return '—';
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '—' : trimmed;
  }
  if (value is num || value is bool) {
    return value.toString();
  }
  if (value is Iterable) {
    final items = value
        .map(_stringifyChangeValue)
        .where((element) => element != '—')
        .toList();
    return items.isEmpty ? '—' : items.join(', ');
  }
  if (value is Map) {
    if (value.isEmpty) return '—';
    final entries = value.entries
        .where((entry) => entry.value != null)
        .map(
          (entry) =>
              '${_formatProvenanceKey(entry.key)}=${_stringifyChangeValue(entry.value)}',
        )
        .take(3)
        .toList();
    if (entries.isEmpty) return '—';
    final result = entries.join(', ');
    return value.length > entries.length ? '$result…' : result;
  }
  return value.toString();
}

String _formatProvenanceKey(String key) {
  if (key.isEmpty) return key;
  final parts = key.split('_').where((part) => part.isNotEmpty);
  return parts
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

String? _formatUpdateType(String updateType) {
  final normalized = updateType.trim();
  if (normalized.isEmpty) return null;
  switch (normalized) {
    case 'genet_type_update':
      return 'Provenance Type';
    case 'quantity_adjustment':
      return 'Quantity';
    default:
      return normalized.replaceAll('_', ' ');
  }
}

String? _fieldLabel(ModelType recordType, String field) {
  if (recordType == ModelType.genet) {
    return _genetFieldLabels[field] ?? field;
  }
  if (recordType == ModelType.organismRecord) {
    return _coralFieldLabels[field] ?? field;
  }
  return field;
}

String _formatFieldValue(String field, Object? value) {
  if (value == null) return '';
  if (value is num || value is bool) {
    return value.toString();
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    switch (field) {
      case 'provenanceTypeId':
      case 'metadata.provenanceTypeId':
        return _provenanceTypeLabelFromId(trimmed) ?? trimmed;
      case 'speciesId':
        return _speciesLabel(trimmed) ?? trimmed;
      case 'lifeStageId':
      case 'metadata.lifeStageId':
        return _lifeStageLabelFromId(trimmed) ?? trimmed;
      case 'physicalForm.formId':
        return _physicalFormLabel(trimmed) ?? trimmed;
      case 'metadata.physicalFormId':
        return _physicalFormLabel(trimmed) ?? trimmed;
      default:
        return trimmed;
    }
  }
  if (value is Iterable) {
    return value
        .map((entry) => entry.toString())
        .where((entry) => entry.trim().isNotEmpty)
        .join(', ');
  }
  if (value is Map) {
    return value.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(', ');
  }
  return value.toString();
}

bool _isSupportedEventType(String? eventTypeId) {
  if (eventTypeId == null ||
      eventTypeId.isEmpty ||
      eventTypeId == Missing.string) {
    return false;
  }
  return _supportedEventTypeIds.contains(eventTypeId);
}

bool _isRelevantRecordType(ModelType? type) =>
    type == ModelType.genet || type == ModelType.organismRecord;

String _eventLabelFor(String? eventTypeId) {
  final sanitized = _sanitizeEventTypeId(eventTypeId);
  if (sanitized == null) {
    return 'Unknown Event';
  }
  if (_eventLabelOverrides.containsKey(sanitized)) {
    return _eventLabelOverrides[sanitized]!;
  }
  return EventType.builtins[sanitized]?.name ?? sanitized;
}

String _geneticsAwareEventLabel(String? eventTypeId, String? provenanceTypeLabel) {
  // For update events with genetics provenance, use provenance type as label
  final sanitized = _sanitizeEventTypeId(eventTypeId);
  if (sanitized == 'event_update' && provenanceTypeLabel != null && provenanceTypeLabel.isNotEmpty) {
    return provenanceTypeLabel; // e.g., "Sexual Cohort", "Wild Collection"
  }
  return _eventLabelFor(eventTypeId);
}

String _recordTypeLabel(ModelType? type) {
  switch (type) {
    case ModelType.genet:
      return 'Genet';
    case ModelType.organismRecord:
      return 'Organism';
    default:
      return '';
  }
}

String? _speciesLabel(String? speciesId) {
  final id = _asNonEmptyString(speciesId);
  if (id == null) return null;
  return SpeciesRegistry.globalById(id)?.name ?? id;
}

String? _provenanceLabelFromTypeId(String? provenanceTypeId) {
  final provenanceType = _provenanceTypeFromId(provenanceTypeId);
  if (provenanceType != null) {
    return provenanceType.displayName;
  }
  return _provenanceTypeLabel(provenanceTypeId);
}

String? _lifeStageLabelFromId(String? lifeStageId) {
  final id = _asNonEmptyString(lifeStageId);
  if (id == null) return null;
  final stage = LifeStageX.tryParse(id);
  return stage?.displayName;
}

String? _provenanceTypeLabelFromId(String? provenanceTypeId) {
  final id = _asNonEmptyString(provenanceTypeId);
  if (id == null) return null;
  final type = ProvenanceTypeX.tryParse(id);
  return type?.displayName;
}

String? _physicalFormLabel(String? physicalFormId) {
  final id = _asNonEmptyString(physicalFormId);
  if (id != null) {
    // Physical form ids are already human-readable; return raw id.
    return id;
  }
  return null;
}

ProvenanceType? _provenanceTypeFromId(String? provenanceTypeId) {
  final id = _asNonEmptyString(provenanceTypeId);
  if (id == null) return null;
  // Parse provenanceTypeId directly
  return ProvenanceTypeX.tryParse(id);
}

String? _provenanceTypeLabel(String? provenanceTypeId) {
  final id = _asNonEmptyString(provenanceTypeId);
  if (id == null) return null;
  // Parse provenanceTypeId and get display name
  final provenanceType = ProvenanceTypeX.tryParse(id);
  if (provenanceType != null) return provenanceType.displayName;
  // Fallback for unknown provenance types
  return id;
}

String _statusLabel(String? raw) {
  final parsed = tryParseTransferStatus(raw) ?? TransferStatus.draft;
  switch (parsed) {
    case TransferStatus.draft:
      return 'Draft';
    case TransferStatus.pending:
      return 'Pending';
    case TransferStatus.shipped:
      return 'Shipped';
    case TransferStatus.received:
      return 'Received';
    case TransferStatus.rejected:
      return 'Rejected';
    case TransferStatus.cancelled:
      return 'Cancelled';
  }
}

String? _asNonEmptyString(Object? value) {
  if (value == null) return null;
  final trimmed = value.toString().trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _sanitizeEventTypeId(String? raw) {
  if (raw == null || raw.isEmpty || raw == Missing.string) {
    return null;
  }
  return raw;
}
