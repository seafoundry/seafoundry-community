// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_cubit.dart';
import 'package:seafoundry_app/cubits/record_display_preferences/record_display_preferences_cubit.dart';
import 'package:seafoundry_app/cubits/summary_statistics/summary_card_filter.dart';
import 'package:seafoundry_app/cubits/summary_statistics/summary_statistics_state.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/health_status.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/theme/app_colors.dart';
import 'package:seafoundry_app/theme/spacing.dart';

import '../common/organism_reference_links.dart';

class FilteredOrganismListSheet extends StatefulWidget {
  const FilteredOrganismListSheet({
    super.key,
    required this.title,
    required this.inventoryCount,
    required this.filter,
    required this.filterState,
    required this.urlPath,
    required this.isOutplantingSite,
    required this.excludeOutplantingSites,
    this.recordCount,
    this.healthStatus,
    this.organizationFilterPredicate,
    this.onRecordSelected,
    this.siteRepository,
    this.groupRepository,
    this.groupLookup,
  });

  final String title;
  final int inventoryCount;
  final int? recordCount;
  final SummaryCardFilter filter;
  final SummaryStatisticsState filterState;
  final String urlPath;
  final bool Function(String siteId) isOutplantingSite;
  final bool excludeOutplantingSites;
  final HealthStatus? healthStatus;
  final bool Function(OrganismRecord record)? organizationFilterPredicate;
  final ValueChanged<OrganismRecord>? onRecordSelected;
  final SiteRepository? siteRepository;
  final GroupRepository? groupRepository;

  /// Optional pre-built group lookup map for hierarchical filtering.
  /// If provided, enables proper superstructure/structure/substructure filtering.
  /// If null and groupRepository is available, the sheet will build its own lookup.
  final Map<String, Group>? groupLookup;

  static Future<void> show(
    BuildContext context, {
    required SummaryCardFilter filter,
    required String urlPath,
    required String title,
    required int inventoryCount,
    int? recordCount,
    SummaryStatisticsState? filterState,
    HealthStatus? healthStatus,
    bool Function(String siteId)? isOutplantingSite,
    bool excludeOutplantingSites = true,
    bool Function(OrganismRecord record)? organizationFilterPredicate,
    ValueChanged<OrganismRecord>? onRecordSelected,
    Map<String, Group>? groupLookup,
  }) {
    // Capture repository from parent context BEFORE showing modal.
    // Modal bottom sheets create a new route that loses parent providers.
    final repository = context.read<OrganismRecordRepository>();
    T? maybeRead<T>() {
      try {
        return context.read<T>();
      } on ProviderNotFoundException {
        return null;
      }
    }

    final siteRepository = maybeRead<SiteRepository>();
    final groupRepository = maybeRead<GroupRepository>();

    final providers = _captureSheetProviders(
      context,
      repository,
      siteRepository: siteRepository,
      groupRepository: groupRepository,
    );
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useRootNavigator: false, // Stay within provider scope
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final sheet = FilteredOrganismListSheet(
          title: title,
          inventoryCount: inventoryCount,
          recordCount: recordCount,
          filter: filter,
          filterState: filterState ?? const SummaryStatisticsState(),
          urlPath: urlPath,
          isOutplantingSite: isOutplantingSite ?? (_) => false,
          excludeOutplantingSites: excludeOutplantingSites,
          healthStatus: healthStatus,
          organizationFilterPredicate: organizationFilterPredicate,
          onRecordSelected: onRecordSelected,
          siteRepository: siteRepository,
          groupRepository: groupRepository,
          groupLookup: groupLookup,
        );
        if (providers.isEmpty) return sheet;
        return MultiProvider(providers: providers, child: sheet);
      },
    );
  }

  @override
  State<FilteredOrganismListSheet> createState() =>
      _FilteredOrganismListSheetState();
}

class _FilteredOrganismListSheetState extends State<FilteredOrganismListSheet> {
  final Map<String, String> _siteNamesById = {};
  final Map<String, String> _groupNamesById = {};
  final Set<String> _requestedSiteIds = {};
  final Set<String> _requestedGroupIds = {};

  /// Determines if hierarchical structure filtering is active.
  /// When true, groupLookup is needed for proper filtering.
  bool get _needsGroupLookup {
    final filterState = widget.filterState;
    return filterState.selectedSuperstructureIds.isNotEmpty ||
        filterState.selectedStructureIds.isNotEmpty ||
        filterState.selectedSubstructureIds.isNotEmpty;
  }

  /// Builds a lookup map from a list of groups.
  Map<String, Group> _buildGroupLookup(List<Group> groups) {
    return {for (final g in groups) g.id: g};
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<OrganismRecordRepository>();
    final stream = repository.streamRecordsForUrlPath(widget.urlPath);
    final countLabel = widget.recordCount == null
        ? widget.inventoryCount.toString()
        : '${widget.inventoryCount} count / ${widget.recordCount} records';

    // Use provided groupLookup, or stream from repository if hierarchical
    // filtering is needed.
    final groupRepo = widget.groupRepository;
    final hasProvidedLookup = widget.groupLookup != null;
    final shouldStreamGroups =
        !hasProvidedLookup && _needsGroupLookup && groupRepo != null;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.md,
                    Spacing.md,
                    Spacing.sm,
                    Spacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${widget.title} ($countLabel)',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: shouldStreamGroups
                      ? StreamBuilder<List<Group>>(
                          stream: groupRepo.streamAll,
                          builder: (context, groupSnapshot) {
                            final groupLookup = groupSnapshot.hasData
                                ? _buildGroupLookup(groupSnapshot.data!)
                                : <String, Group>{};
                            return _buildOrganismList(
                              stream: stream,
                              scrollController: scrollController,
                              groupLookup: groupLookup,
                            );
                          },
                        )
                      : _buildOrganismList(
                          stream: stream,
                          scrollController: scrollController,
                          groupLookup: widget.groupLookup,
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrganismList({
    required Stream<List<OrganismRecord>> stream,
    required ScrollController scrollController,
    Map<String, Group>? groupLookup,
  }) {
    return StreamBuilder<List<OrganismRecord>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text('Failed to load organisms.'),
          );
        }

        final records = snapshot.data ?? const <OrganismRecord>[];
        final orgFilterPredicate = widget.organizationFilterPredicate;
        final scopedRecords = orgFilterPredicate == null
            ? records
            : records.where(orgFilterPredicate);
        final predicate = widget.filter.predicate(
          isOutplantingSite: widget.isOutplantingSite,
          filterState: widget.filterState,
          status: widget.healthStatus ?? widget.filterState.selectedHealth,
          excludeOutplantingSites: widget.excludeOutplantingSites,
          groupLookup: groupLookup,
        );
        var filtered = scopedRecords
            .where(predicate)
            .where(_hasPositiveQuantity)
            .toList();
        if (widget.filter == SummaryCardFilter.byGenotype) {
          final seen = <String>{};
          filtered = filtered.where((record) {
            final genetId = GenetIdResolver.resolve(record);
            if (genetId == null || genetId.isEmpty) {
              return false;
            }
            if (seen.contains(genetId)) return false;
            seen.add(genetId);
            return true;
          }).toList();
        }
        final displayPrefs =
            context.watch<RecordDisplayPreferencesCubit>().state;
        filtered.sort((a, b) {
          final aLabel = _primaryLabel(a, displayPrefs);
          final bLabel = _primaryLabel(b, displayPrefs);
          return aLabel.compareTo(bLabel);
        });

        if (filtered.isEmpty) {
          return const Center(
            child: Text('No matching organisms found.'),
          );
        }

        _ensureLocationNames(filtered);

        final onSelected = widget.onRecordSelected;
        return ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.all(Spacing.md),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final record = filtered[index];
            final displayInfo = resolveRecordDisplayInfo(
              showUuid: displayPrefs.showUuid,
              showIdentifier: displayPrefs.showIdentifier,
              recordId: record.id,
              tagId: record.tagId,
              localGenetId: record.localGenetId,
            );
            return _OrganismListTile(
              record: record,
              displayInfo: displayInfo,
              subtitle: _buildBreadcrumb(record),
              detailsLine: _buildDetailsLine(record),
              quantity: _formatQuantity(record),
              healthStatus: record.healthStatus,
              onTap: onSelected == null
                  ? null
                  : () {
                      // Pop using the modal's context (from itemBuilder)
                      // This ensures the modal closes correctly
                      Navigator.of(context).pop();
                      // Then invoke the callback to navigate
                      onSelected(record);
                    },
            );
          },
        );
      },
    );
  }

  void _ensureLocationNames(Iterable<OrganismRecord> records) {
    final siteRepository = widget.siteRepository;
    final groupRepository = widget.groupRepository;
    if (siteRepository == null && groupRepository == null) return;

    final siteIds = <String>{};
    final groupIds = <String>{};

    for (final record in records) {
      final siteId = _normalizeId(record.siteId);
      if (siteRepository != null &&
          siteId != null &&
          !_requestedSiteIds.contains(siteId)) {
        siteIds.add(siteId);
      }

      final groupId = _normalizeId(record.groupId);
      if (groupRepository != null &&
          groupId != null &&
          !_requestedGroupIds.contains(groupId)) {
        groupIds.add(groupId);
      }
    }

    if (siteIds.isEmpty && groupIds.isEmpty) return;
    _loadLocationNames(siteIds: siteIds, groupIds: groupIds);
  }

  Future<void> _loadLocationNames({
    required Set<String> siteIds,
    required Set<String> groupIds,
  }) async {
    final siteRepository = widget.siteRepository;
    final groupRepository = widget.groupRepository;
    if (siteRepository == null && groupRepository == null) return;

    final resolvedSiteIds = siteRepository == null ? <String>{} : siteIds;
    final resolvedGroupIds = groupRepository == null ? <String>{} : groupIds;
    _requestedSiteIds.addAll(resolvedSiteIds);
    _requestedGroupIds.addAll(resolvedGroupIds);

    final newSiteNames = <String, String>{};
    if (siteRepository != null && resolvedSiteIds.isNotEmpty) {
      final results = await Future.wait(
        resolvedSiteIds.map((id) async {
          try {
            final site = await siteRepository.getRecordForId(id);
            return MapEntry(id, site?.name);
          } catch (_) {
            return MapEntry(id, null);
          }
        }),
      );
      for (final entry in results) {
        final name = _normalizeLabel(entry.value);
        if (name != null) {
          newSiteNames[entry.key] = name;
        }
      }
    }

    final newGroupNames = <String, String>{};
    if (groupRepository != null && resolvedGroupIds.isNotEmpty) {
      final results = await Future.wait(
        resolvedGroupIds.map((id) async {
          try {
            final group = await groupRepository.getRecordForId(id);
            return MapEntry(id, group?.name);
          } catch (_) {
            return MapEntry(id, null);
          }
        }),
      );
      for (final entry in results) {
        final name = _normalizeLabel(entry.value);
        if (name != null) {
          newGroupNames[entry.key] = name;
        }
      }
    }

    if (!mounted) return;
    if (newSiteNames.isEmpty && newGroupNames.isEmpty) return;
    setState(() {
      _siteNamesById.addAll(newSiteNames);
      _groupNamesById.addAll(newGroupNames);
    });
  }

  String _buildBreadcrumb(OrganismRecord record) {
    final resolved = _buildResolvedBreadcrumb(record);
    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }
    final fallback = _buildPathBreadcrumb(record.urlPath);
    if (fallback.isNotEmpty) {
      return fallback;
    }
    final idFallback = _buildIdBreadcrumb(record);
    return idFallback ?? 'Unknown location';
  }

  String? _buildResolvedBreadcrumb(OrganismRecord record) {
    final siteId = _normalizeId(record.siteId);
    final groupId = _normalizeId(record.groupId);
    final siteName = siteId != null ? _siteNamesById[siteId] : null;
    final groupName = groupId != null ? _groupNamesById[groupId] : null;
    final resolvedSite = _normalizeLabel(siteName);
    final resolvedGroup = _normalizeLabel(groupName);

    if (resolvedSite == null && resolvedGroup == null) return null;
    if (resolvedGroup == null || resolvedGroup == resolvedSite) {
      return resolvedSite ?? resolvedGroup;
    }
    if (resolvedSite == null) return resolvedGroup;
    return '$resolvedSite -> $resolvedGroup';
  }

  String _buildPathBreadcrumb(String urlPath) {
    final path = urlPath;
    if (path.isEmpty) return 'Unknown location';
    final segments = path
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .toList();
    if (segments.length < 2) return 'Organization';
    final site = _formatSegment(segments[1]);
    if (segments.length < 3) return site;
    final group = _formatSegment(segments[2]);
    return '$site -> $group';
  }

  String? _buildIdBreadcrumb(OrganismRecord record) {
    final siteId = _normalizeId(record.siteId);
    final groupId = _normalizeId(record.groupId);
    final siteLabel = siteId != null ? _formatSegment(siteId) : null;
    final groupLabel = groupId != null ? _formatSegment(groupId) : null;

    if (siteLabel == null && groupLabel == null) return null;
    if (groupLabel == null || groupLabel == siteLabel) {
      return siteLabel ?? groupLabel;
    }
    if (siteLabel == null) return groupLabel;
    return '$siteLabel -> $groupLabel';
  }

  String? _normalizeId(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == Missing.string) return null;
    return trimmed;
  }

  String? _normalizeLabel(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == Missing.string) return null;
    return trimmed;
  }

  String _formatSegment(String value) {
    final normalized = value.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    if (normalized.isEmpty) return value;
    final withSpacing = normalized
        .replaceAllMapped(
          RegExp(r'([a-zA-Z])([0-9])'),
          (match) => '${match[1]} ${match[2]}',
        )
        .replaceAllMapped(
          RegExp(r'([0-9])([a-zA-Z])'),
          (match) => '${match[1]} ${match[2]}',
        );
    return withSpacing.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _formatQuantity(OrganismRecord record) {
    final value = record.measurement.value;
    final unit = record.measurement.unit.symbol;
    final display = value % 1 == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$display $unit';
  }

  String _buildDetailsLine(OrganismRecord record) {
    final formId = record.physicalForm?.formId;
    final provenanceType = record.provenanceType;
    final parts = <String>[
      record.lifeStage.displayName,
      if (formId != null) formId,
      if (provenanceType != null) provenanceType.displayName,
    ];
    return parts.join(' • ');
  }

  bool _hasPositiveQuantity(OrganismRecord record) {
    return record.measurement.value > 0;
  }

  String _primaryLabel(
    OrganismRecord record,
    RecordDisplayPreferencesState displayPrefs,
  ) {
    final displayInfo = resolveRecordDisplayInfo(
      showUuid: displayPrefs.showUuid,
      showIdentifier: displayPrefs.showIdentifier,
      recordId: record.id,
      tagId: record.tagId,
      localGenetId: record.localGenetId,
    );
    final label = displayInfo.tagId.trim();
    if (label.isNotEmpty) {
      return label.toLowerCase();
    }
    if (record.slug.isNotEmpty) {
      return record.slug.toLowerCase();
    }
    return record.id.toLowerCase();
  }
}

List<SingleChildWidget> _captureSheetProviders(
  BuildContext context,
  OrganismRecordRepository repository, {
  SiteRepository? siteRepository,
  GroupRepository? groupRepository,
}) {
  final providers = <SingleChildWidget>[
    Provider<OrganismRecordRepository>.value(value: repository),
    if (siteRepository != null)
      Provider<SiteRepository>.value(value: siteRepository),
    if (groupRepository != null)
      Provider<GroupRepository>.value(value: groupRepository),
  ];

  void addBloc<T extends BlocBase<dynamic>>() {
    try {
      final bloc = context.read<T>();
      providers.add(BlocProvider<T>.value(value: bloc));
    } on ProviderNotFoundException {
      // Sheet can still render without this provider.
    }
  }

  addBloc<CurrentUser>();
  addBloc<NavigationCubit>();
  addBloc<RecordDisplayPreferencesCubit>();

  return providers;
}

class _OrganismListTile extends StatelessWidget {
  const _OrganismListTile({
    required this.record,
    required this.displayInfo,
    required this.subtitle,
    required this.detailsLine,
    required this.quantity,
    required this.healthStatus,
    this.onTap,
  });

  final OrganismRecord record;
  final RecordDisplayInfo displayInfo;
  final String subtitle;
  final String detailsLine;
  final String quantity;
  final HealthStatus healthStatus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final genetId = GenetIdResolver.resolve(record);
    final hasReference =
        displayInfo.tagId.trim().isNotEmpty ||
        (displayInfo.localGenetId ?? '').trim().isNotEmpty;

    return ListTile(
      onTap: onTap,
      title: Row(
        children: [
          Expanded(
            child: hasReference
                ? OrganismReferenceLinks(
                    tagId: displayInfo.tagId,
                    localGenetId: displayInfo.localGenetId,
                    urlPath: record.urlPath,
                    genetId: genetId,
                    showUnderline: false,
                    disableNavigation: true,
                  )
                : Text(
                    displayInfo.tagId,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (detailsLine.isNotEmpty)
            Text(
              detailsLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            quantity,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          _HealthChip(status: healthStatus),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ],
      ),
    );
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({required this.status});

  final HealthStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _statusColor(status),
        ),
      ),
    );
  }

  Color _statusColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.healthy:
        return AppColors.success;
      case HealthStatus.stressed:
        return AppColors.warning;
      case HealthStatus.diseased:
        return AppColors.error;
      case HealthStatus.recovering:
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }
}
