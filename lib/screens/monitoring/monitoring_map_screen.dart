// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/extensions/site_type_extensions.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/monitoring_event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/feature_access_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/widgets/common/tier_paywall.dart';
import 'package:seafoundry_app/widgets/map/geometry_map.dart';
import 'package:seafoundry_app/widgets/map/geometry_preview_adapter.dart';
import 'package:seafoundry_app/widgets/map/outplant_google_map.dart';

/// Aggregated monitoring/outplant map that renders geometry overlays for a site.
/// This screen shows events, analytics, and data exports for monitoring.
class MonitoringMapScreen extends StatefulWidget {
  const MonitoringMapScreen({
    super.key,
    this.usePreview = false,
    this.restrictToMonitoringOnlySites = false,
  });

  final bool usePreview;
  final bool restrictToMonitoringOnlySites;

  static Route<void> route({
    bool usePreview = false,
    bool restrictToMonitoringOnlySites = false,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => MonitoringMapScreen(
        usePreview: usePreview,
        restrictToMonitoringOnlySites: restrictToMonitoringOnlySites,
      ),
    );
  }

  @override
  State<MonitoringMapScreen> createState() => _MonitoringMapScreenState();
}

class _MonitoringMapScreenState extends State<MonitoringMapScreen> {
  Site? _selectedSite;
  final Set<String> _selectedSpecies = <String>{};
  final Set<HealthStatus> _selectedHealthStatuses = <HealthStatus>{};
  DateTimeRange? _dateRange;
  bool _showBounds = true;
  bool _showOutplants = true;
  bool _showMonitoring = true;
  static const double _mapHeight = 400.0;

  @override
  Widget build(BuildContext context) {
    final monitoringAccess = _maybeReadFeatureAccess(context);
    final monitoringEnabled =
        monitoringAccess?.isFeatureEnabled('monitoring_kml') ?? true;
    if (!monitoringEnabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Monitoring Map')),
        body: const TierPaywall(
          title: 'Monitoring maps - coming soon',
          subtitle:
              'Upgrade to unlock interactive monitoring overlays, geometry filters, and map exports.',
          featureName: 'Monitoring Maps',
          requiredTier: Tier.pro,
        ),
      );
    }

    final siteRepository = RepositoryProvider.of<SiteRepository>(context);
    final eventRepository = RepositoryProvider.of<EventRepository>(context);
    final monitoringEventRepository =
        RepositoryProvider.of<MonitoringEventRepository>(context);

    return StreamBuilder<List<Site>>(
      stream: siteRepository.streamAll,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          // Suppress permission-denied errors during navigation/logout
          // These are expected when RepositoriesProvider is disposed
          final errorStr = snapshot.error.toString().toLowerCase();
          if (errorStr.contains('permission-denied') ||
              errorStr.contains('permission denied') ||
              errorStr.contains('missing or insufficient permissions')) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(child: Text('Failed to load sites: ${snapshot.error}'));
        }

        final sites = snapshot.data ?? const <Site>[];
        final visibleSites = widget.restrictToMonitoringOnlySites
            ? sites.monitoringSites.toList()
            : sites;
        if (visibleSites.isEmpty) {
          final message = widget.restrictToMonitoringOnlySites
              ? 'No baseline or reference sites yet. Create one to view monitoring.'
              : 'No sites available yet. Create a site to view the map.';
          return _EmptyState(message: message);
        }

        final currentSite = _selectedSite == null
            ? visibleSites.first
            : visibleSites.firstWhere(
                (site) => site.id == _selectedSite!.id,
                orElse: () => visibleSites.first,
              );
        if (_selectedSite == null || _selectedSite!.id != currentSite.id) {
          _scheduleSiteSelection(currentSite);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildSiteSelector(visibleSites, currentSite),
            ),
            Expanded(
              child: StreamBuilder<List<OutplantEvent>>(
                stream: eventRepository.streamOutplantEvents(
                  siteId: currentSite.id,
                  limit: 200,
                ),
                builder: (context, outplantSnapshot) {
                  if (outplantSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (outplantSnapshot.hasError) {
                    return Center(
                      child: Text(
                        'Failed to load outplant events: ${outplantSnapshot.error}',
                      ),
                    );
                  }

                  final outplantEvents =
                      outplantSnapshot.data ?? const <OutplantEvent>[];

                  final speciesIds = _extractSpecies(outplantEvents);
                  _coerceSelectedSpecies(speciesIds);

                  final filteredOutplants = _filterOutplantEvents(
                    outplantEvents,
                  );
                  final outplantById = {
                    for (final event in filteredOutplants) event.id: event,
                  };

                  return StreamBuilder<List<MonitoringEventRecord>>(
                    stream: monitoringEventRepository.streamMonitoringEvents(
                      siteId: currentSite.id,
                    ),
                    builder: (context, monitoringSnapshot) {
                      if (monitoringSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (monitoringSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Failed to load monitoring events: ${monitoringSnapshot.error}',
                          ),
                        );
                      }

                      final monitoringEvents =
                          monitoringSnapshot.data ??
                          const <MonitoringEventRecord>[];
                      final filteredMonitoring = _filterMonitoringEvents(
                        monitoringEvents,
                        outplantById,
                      );

                      final mapWidget = _buildMap(
                        currentSite: currentSite,
                        outplantEvents: filteredOutplants,
                        monitoringEvents: filteredMonitoring,
                      );

                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        children: [
                          _buildSpeciesFilters(speciesIds),
                          const SizedBox(height: 12),
                          _buildHealthFilters(),
                          const SizedBox(height: 12),
                          _buildDateFilter(context),
                          const SizedBox(height: 12),
                          _buildMapToggles(),
                          const SizedBox(height: 12),
                          mapWidget,
                          const SizedBox(height: 16),
                          ..._buildEventEntries(
                            filteredOutplants,
                            filteredMonitoring,
                            outplantById,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMap({
    required Site currentSite,
    required List<OutplantEvent> outplantEvents,
    required List<MonitoringEventRecord> monitoringEvents,
  }) {
    if (widget.usePreview) {
      final previewSeries = [
        GeometryPreviewAdapter.siteSeries(currentSite),
        ...GeometryPreviewAdapter.outplantSeries(outplantEvents),
      ].whereType<GeometrySeries>().toList(growable: false);
      return GeometryMap(
        series: previewSeries,
        siteBounds: currentSite.bounds,
        siteCentroid: currentSite.centroid ?? _fallbackCentroid(currentSite),
        showBounds: _showBounds,
        emptyLabel: 'No geometry recorded for ${currentSite.name} yet.',
        maxHeight: 260,
      );
    }

    return SizedBox(
      height: _mapHeight,
      child: OutplantGoogleMap(
        outplantEvents: _showOutplants
            ? outplantEvents
            : const <OutplantEvent>[],
        monitoringEvents: _showMonitoring
            ? monitoringEvents
            : const <MonitoringEventRecord>[],
        siteGeometry: currentSite.geometry,
        siteBounds: currentSite.bounds,
        siteCentroid: currentSite.centroid ?? _fallbackCentroid(currentSite),
        showSiteBounds: _showBounds,
        showOutplantMarkers: _showOutplants,
        showMonitoringMarkers: _showMonitoring,
        showKmlOverlays: _showOutplants,
        onOutplantMarkerTap: _openOutplantDetails,
        onMonitoringMarkerTap: _openMonitoringDetails,
      ),
    );
  }

  Widget _buildSiteSelector(List<Site> sites, Site currentSite) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<Site>(
            initialValue: currentSite,
            decoration: const InputDecoration(
              labelText: 'Site',
              border: OutlineInputBorder(),
            ),
            items: sites
                .map(
                  (site) => DropdownMenuItem<Site>(
                    value: site,
                    child: Text(site.name),
                  ),
                )
                .toList(growable: false),
            onChanged: (site) {
              if (site == null) return;
              _resetFiltersForSite(site);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSpeciesFilters(Set<String> speciesIds) {
    if (speciesIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final chips = speciesIds.map((id) {
      final species = SpeciesRegistry.globalById(id);
      final label = species?.name ?? id.toUpperCase();
      final selected = _selectedSpecies.contains(id);
      return FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (value) {
          setState(() {
            if (value) {
              _selectedSpecies.add(id);
            } else {
              _selectedSpecies.remove(id);
            }
          });
        },
      );
    }).toList();

    return Wrap(spacing: 8, runSpacing: 4, children: chips);
  }

  Widget _buildHealthFilters() {
    final chips = HealthStatus.selectableValues.map((status) {
      final selected = _selectedHealthStatuses.contains(status);
      return FilterChip(
        label: Text(status.displayName),
        selected: selected,
        onSelected: (value) {
          setState(() {
            if (value) {
              _selectedHealthStatuses.add(status);
            } else {
              _selectedHealthStatuses.remove(status);
            }
          });
        },
      );
    }).toList();

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(spacing: 8, runSpacing: 4, children: chips);
  }

  Widget _buildDateFilter(BuildContext context) {
    final label = _dateRange == null
        ? 'Date range'
        : '${_formattedDate(_dateRange!.start)} – ${_formattedDate(_dateRange!.end)}';

    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.calendar_month),
        label: Text(label),
        onPressed: () async {
          final now = DateTime.now();
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(now.year - 5),
            lastDate: DateTime(now.year + 5),
            initialDateRange: _dateRange,
          );
          if (picked != null) {
            setState(() => _dateRange = picked);
          }
        },
      ),
    );
  }

  Widget _buildMapToggles() {
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          label: const Text('Show outplants'),
          selected: _showOutplants,
          onSelected: (value) => setState(() => _showOutplants = value),
        ),
        FilterChip(
          label: const Text('Show monitoring'),
          selected: _showMonitoring,
          onSelected: (value) => setState(() => _showMonitoring = value),
        ),
        FilterChip(
          label: const Text('Show site bounds'),
          selected: _showBounds,
          onSelected: (value) => setState(() => _showBounds = value),
        ),
      ],
    );
  }

  Future<void> _openOutplantDetails(List<OutplantEvent> events) async {
    if (!mounted || events.isEmpty) return;
    final sorted = [...events]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final tiles = sorted.map((event) {
      final created = DateTime.tryParse(event.createdAt);
      final speciesCodes = event.allocations
          .map(
            (allocation) =>
                SpeciesRegistry.globalById(allocation.speciesId)?.code ??
                allocation.speciesId.toUpperCase(),
          )
          .where((code) => code.isNotEmpty)
          .toSet();
      final geometry = event.geometry;
      final metrics = <String>[];
      if (created != null) {
        metrics.add('Date: ${_formattedDate(created)}');
      }
      metrics.add('Fragments: ${event.totalQuantity}');
      if (speciesCodes.isNotEmpty) {
        metrics.add('Species: ${speciesCodes.join(', ')}');
      }
      if (geometry != null) {
        metrics.add(
          'Geometry: ${geometry.type.name} (${geometry.coordinates.length} pts)',
        );
      } else {
        metrics.add('Geometry: none');
      }
      final comment = event.comment;
      return ListTile(
        isThreeLine: comment != null && comment.isNotEmpty,
        title: Text(event.name),
        subtitle: Text(
          [
            metrics.join(' • '),
            if (comment != null && comment.isNotEmpty) 'Notes: $comment',
          ].join('\n'),
        ),
      );
    }).toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => _ClusterSheet(
        title: sorted.length == 1
            ? 'Outplant Event'
            : '${sorted.length} Outplant Events',
        children: tiles,
      ),
    );
  }

  Future<void> _openMonitoringDetails(
    List<MonitoringEventRecord> events,
  ) async {
    if (!mounted || events.isEmpty) return;
    final sorted = [...events]
      ..sort((a, b) {
        final aDate = _monitoringDateFor(a);
        final bDate = _monitoringDateFor(b);
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

    final tiles = sorted.map((event) {
      final date = _monitoringDateFor(event);
      final health = event.newHealthStatus ?? event.healthStatus ?? 'n/a';
      final metrics = <String>[];
      if (event.percentCover != null) {
        metrics.add('Cover: ${event.percentCover!.toStringAsFixed(1)}%');
      }
      if (event.percentBleaching != null) {
        metrics.add(
          'Bleaching: ${event.percentBleaching!.toStringAsFixed(1)}%',
        );
      }
      if (event.percentDisease != null) {
        metrics.add('Disease: ${event.percentDisease!.toStringAsFixed(1)}%');
      }
      final subtitleLines = <String>[
        if (date != null) 'Date: ${_formattedDate(date)}',
        'Health: $health',
        if (metrics.isNotEmpty) metrics.join(' • '),
        if (event.totalCount != null) 'Entries: ${event.totalCount}',
      ];
      if (event.notes != null && event.notes!.isNotEmpty) {
        subtitleLines.add('Notes: ${event.notes}');
      }
      if (event.comment != null && event.comment!.isNotEmpty) {
        subtitleLines.add('Comment: ${event.comment}');
      }
      return ListTile(
        isThreeLine: subtitleLines.length > 2,
        title: Text(event.outplantEventNameSnapshot ?? 'Monitoring'),
        subtitle: Text(subtitleLines.join('\n')),
      );
    }).toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => _ClusterSheet(
        title: sorted.length == 1
            ? 'Monitoring Entry'
            : '${sorted.length} Monitoring Entries',
        children: tiles,
      ),
    );
  }

  Set<String> _extractSpecies(List<OutplantEvent> events) {
    final ids = <String>{};
    for (final event in events) {
      for (final allocation in event.allocations) {
        if (allocation.speciesId.isNotEmpty) {
          ids.add(allocation.speciesId);
        }
      }
    }
    return ids;
  }

  void _coerceSelectedSpecies(Set<String> speciesIds) {
    final toRemove = _selectedSpecies.difference(speciesIds);
    if (toRemove.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedSpecies.removeAll(toRemove));
      });
    }
  }

  bool _matchesDateRange(DateTime? candidate) {
    if (_dateRange == null || candidate == null) {
      return true;
    }
    final start = DateTime(
      _dateRange!.start.year,
      _dateRange!.start.month,
      _dateRange!.start.day,
    );
    final end = DateTime(
      _dateRange!.end.year,
      _dateRange!.end.month,
      _dateRange!.end.day,
      23,
      59,
      59,
      999,
    );
    return !candidate.isBefore(start) && !candidate.isAfter(end);
  }

  DateTime? _monitoringDateFor(MonitoringEventRecord event) {
    if (event.monitoringDate != null) {
      return event.monitoringDate;
    }
    return DateTime.tryParse(event.createdAt);
  }

  List<OutplantEvent> _filterOutplantEvents(List<OutplantEvent> events) {
    final filteredByDate = events.where((event) {
      if (_dateRange == null) {
        return true;
      }
      final createdAt = DateTime.tryParse(event.createdAt);
      return _matchesDateRange(createdAt);
    }).toList();

    if (_selectedSpecies.isEmpty) {
      return filteredByDate;
    }

    return filteredByDate
        .where(
          (event) => event.allocations.any(
            (allocation) => _selectedSpecies.contains(allocation.speciesId),
          ),
        )
        .toList();
  }

  List<MonitoringEventRecord> _filterMonitoringEvents(
    List<MonitoringEventRecord> events,
    Map<String, OutplantEvent> outplantById,
  ) {
    return events.where((event) {
      if (_dateRange != null) {
        final date = _monitoringDateFor(event);
        if (!_matchesDateRange(date)) {
          return false;
        }
      }

      if (_selectedHealthStatuses.isNotEmpty) {
        final health = HealthStatus.maybeFromId(
          event.newHealthStatus ?? event.healthStatus,
        );
        if (health == null || !_selectedHealthStatuses.contains(health)) {
          return false;
        }
      }

      if (_selectedSpecies.isNotEmpty) {
        final outplant = outplantById[event.outplantEventId];
        if (outplant == null) {
          return false;
        }
        final species = outplant.allocations
            .map((allocation) => allocation.speciesId)
            .toSet();
        if (!species.any(_selectedSpecies.contains)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<Widget> _buildEventEntries(
    List<OutplantEvent> outplantEvents,
    List<MonitoringEventRecord> monitoringEvents,
    Map<String, OutplantEvent> outplantById,
  ) {
    final entries = <Widget>[];

    if (outplantEvents.isNotEmpty) {
      entries.add(const ListTile(dense: true, title: Text('Outplant events')));
      entries.addAll(
        outplantEvents.map(
          (event) => ListTile(
            leading: const Icon(Icons.park_outlined),
            title: Text(event.name),
            subtitle: Text(
              '${event.totalQuantity} fragments • '
              '${event.createdAt.substring(0, 10)}',
            ),
            onTap: () => _openOutplantDetails(<OutplantEvent>[event]),
          ),
        ),
      );
    }

    if (monitoringEvents.isNotEmpty) {
      entries.add(
        const ListTile(dense: true, title: Text('Monitoring events')),
      );
      entries.addAll(
        monitoringEvents.map((event) {
          final outplant = outplantById[event.outplantEventId];
          final species =
              outplant?.allocations
                  .map(
                    (allocation) =>
                        SpeciesRegistry.globalById(
                          allocation.speciesId,
                        )?.code ??
                        allocation.speciesId.toUpperCase(),
                  )
                  .toSet()
                  .join(', ') ??
              'Unknown';
          final date = event.monitoringDate != null
              ? _formattedDate(event.monitoringDate!)
              : event.createdAt.substring(0, 10);
          final health = event.newHealthStatus ?? event.healthStatus ?? 'n/a';
          return ListTile(
            leading: const Icon(Icons.health_and_safety_outlined),
            title: Text(event.outplantEventNameSnapshot ?? 'Monitoring'),
            subtitle: Text('$date • Health: $health • Species: $species'),
            onTap: () => _openMonitoringDetails(<MonitoringEventRecord>[event]),
          );
        }),
      );
    }

    if (entries.isEmpty) {
      entries.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('No events match the current filters yet.'),
        ),
      );
    }

    return entries;
  }

  GeoCoordinate? _fallbackCentroid(Site site) {
    if (site.latitude != null && site.longitude != null) {
      return GeoCoordinate(
        latitude: site.latitude!,
        longitude: site.longitude!,
      );
    }
    return null;
  }

  String _formattedDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _scheduleSiteSelection(Site site) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _selectedSite = site);
    });
  }

  void _resetFiltersForSite(Site site) {
    setState(() {
      _selectedSite = site;
      _selectedSpecies.clear();
      _selectedHealthStatuses.clear();
      _dateRange = null;
    });
  }

  FeatureAccessService? _maybeReadFeatureAccess(BuildContext context) {
    try {
      return context.watch<FeatureAccessService>();
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to read FeatureAccessService from widget context',
        e,
        stackTrace,
      );
      return null;
    }
  }
}

/// Simple reusable container for cluster details shown in bottom sheets.
class _ClusterSheet extends StatelessWidget {
  const _ClusterSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: children.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) => children[index],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: Theme.of(context).hintColor),
        textAlign: TextAlign.center,
      ),
    );
  }
}
