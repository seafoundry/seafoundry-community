// @tier: community
import 'dart:async';

import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/monitoring_event_record.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/monitoring/monitoring_entry.dart';
import 'package:seafoundry_app/models/monitoring/organism_monitoring_data.dart';
import 'package:seafoundry_app/models/records/archive_metadata.dart';
import 'package:seafoundry_app/models/types/coral_morphology.dart';
import 'package:seafoundry_app/models/types/health_status.dart';
import 'package:seafoundry_app/models/types/population_loss_reason.dart';
import 'package:seafoundry_app/repositories/inventory/monitoring_event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/event_propagation_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/monitoring_schedule_service.dart';
import 'package:seafoundry_app/services/snapshot_service.dart';
import 'package:seafoundry_app/utils/date_time_converter.dart';
import 'package:seafoundry_app/utils/performance_analyzer.dart';

/// Callback type for deliverable progress updates on monitoring events.
/// This allows pro-tier services to hook into monitoring without creating
/// a tier dependency.
typedef OnMonitoringEventCallback =
    Future<void> Function(
      String eventId, {
      required MonitoringEventRecord monitoringEvent,
      required String? siteId,
      required String organizationId,
    });

/// Service for recording monitoring events and propagating activity updates.
class MonitoringService {
  final MonitoringEventRepository _monitoringEventRepository;
  final OrganismRecordRepository _organismRecordRepository;
  final SnapshotService _snapshotService;
  // EventPropagationService would be used in a real implementation
  // Currently unused as we're just logging events
  // This will be used when event propagation is fully implemented
  // ignore: unused_field
  final EventPropagationService _eventPropagationService;
  // ignore: unused_field
  final MonitoringScheduleService? _scheduleService;
  final OnMonitoringEventCallback? _onMonitoringEventCallback;
  final bool _featureEnabled;
  final String featureKey;

  MonitoringService({
    required MonitoringEventRepository monitoringEventRepository,
    required OrganismRecordRepository organismRecordRepository,
    required SnapshotService snapshotService,
    required EventPropagationService eventPropagationService,
    MonitoringScheduleService? scheduleService,
    OnMonitoringEventCallback? onMonitoringEventCallback,
    bool featureEnabled = true,
    this.featureKey = 'monitoring_dialog',
  }) : _monitoringEventRepository = monitoringEventRepository,
       _organismRecordRepository = organismRecordRepository,
       _snapshotService = snapshotService,
       _eventPropagationService = eventPropagationService,
       _scheduleService = scheduleService,
       _onMonitoringEventCallback = onMonitoringEventCallback,
       _featureEnabled = featureEnabled;

  /// Validates that an organism is alive and can be monitored.
  ///
  /// Throws [ArgumentError] if:
  /// - The organism has a deceased or lost health status
  /// - The organism has zero or negative population
  ///
  /// **Note on TOCTOU (Time-of-check to time-of-use):**
  /// This validation is subject to a race condition where the organism's state
  /// could change between validation and event creation. The window is minimized
  /// by calling [_refreshAndValidateOrganism] immediately before the write.
  /// For strict consistency, consider using Firestore transactions in the future.
  void _validateOrganismAlive(OrganismRecord organism) {
    // Check health status
    final healthStatusId = organism.metadata?['healthStatus'] as String?;
    if (healthStatusId == HealthStatus.deceased.id ||
        healthStatusId == HealthStatus.lost.id) {
      throw ArgumentError(
        'Cannot create monitoring event for deceased/lost organism "${organism.localId ?? organism.id}".',
      );
    }

    // Check population
    final population = organism.measurement.value.toInt();
    if (population <= 0) {
      throw ArgumentError(
        'Cannot create monitoring event for organism with zero population "${organism.localId ?? organism.id}".',
      );
    }
  }

  /// Refreshes organism state from the database and re-validates.
  /// This minimizes the TOCTOU window by fetching the latest state
  /// immediately before the write operation.
  ///
  /// Returns the refreshed organism record if valid.
  /// Throws [ArgumentError] if the organism is no longer valid.
  Future<OrganismRecord> _refreshAndValidateOrganism(
    OrganismRecord organism,
  ) async {
    final refreshed = await _organismRecordRepository.getRecordForId(
      organism.id,
    );
    if (refreshed == null) {
      throw ArgumentError(
        'Organism "${organism.localId ?? organism.id}" no longer exists.',
      );
    }
    _validateOrganismAlive(refreshed);
    return refreshed;
  }

  /// Creates a monitoring event and propagates activity up the graph.
  Future<MonitoringEventRecord?> createMonitoringEvent({
    required GraphNode node,
    required OrganismMonitoringData data,
    EventPermitMetadata? permitMetadata,
  }) async {
    _ensureFeatureEnabled();
    return PerformanceAnalyzer.measure(
      'MonitoringService.createMonitoringEvent',
      () async {
        try {
          // Wait for node to be loaded
          await node.awaitLoaded();

          // Get the record from the node
          // Check if node is loaded
          if (node.state is! GraphLoadedState) {
            LoggingService.instance.error(
              'Failed to get record from node for monitoring event',
            );
            return null;
          }

          // Get the record using node.state.record (main's pattern)
          var record = node.state.record;

          // Validate organism is alive and can be monitored.
          // Use refresh-and-validate to minimize TOCTOU window.
          if (record is OrganismRecord) {
            record = await _refreshAndValidateOrganism(record);
          }

          final entry = _buildMonitoringEntry(data);
          final combinedMeasurements = entry.measurements;

          final event = await _monitoringEventRepository.createMonitoringEvent(
            forRecord: record,
            oldHealthStatus: data.oldHealthStatus.id,
            newHealthStatus: data.newHealthStatus?.id,
            healthIssueTypeId: data.healthIssueTypeId,
            comment: data.comment,
            imageUrl: data.imageUrl,
            percentCover: data.percentCover,
            percentBleaching: data.percentBleaching,
            percentDisease: data.percentDisease,
            measurements: (combinedMeasurements?.isEmpty ?? true)
                ? null
                : Map<String, dynamic>.from(combinedMeasurements!),
            siteId: data.siteId,
            monitoringDate: data.monitoringDate,
            organismIds: [data.organismId],
            createTask: data.createTask,
            entries: [entry],
            totalCount: 1,
            imageAttachments:
                const [], // Individual events don't have attachments
            base: permitMetadata == null
                ? const EventBaseParams()
                : EventBaseParams(permitMetadata: permitMetadata),
          );

          final hasHealthUpdate =
              data.newHealthStatus != null &&
              data.newHealthStatus != data.oldHealthStatus;
          final monitoringCount = _monitoringCount(data.measurements);
          final shouldArchiveForZero =
              record is OrganismRecord &&
              monitoringCount != null &&
              monitoringCount <= 0;

          // Update the organism record if health status changed or monitoring zeroes it out.
          if ((hasHealthUpdate || shouldArchiveForZero) &&
              record is OrganismRecord) {
            final now = DateTime.now().toIso8601String();
            final updatedMetadata = Map<String, dynamic>.from(
              record.metadata ?? {},
            );
            if (hasHealthUpdate) {
              updatedMetadata['healthStatus'] = data.newHealthStatus!.id;
            }
            if (shouldArchiveForZero) {
              updatedMetadata[kArchivedFlagKey] = true;
              updatedMetadata[kArchivedAtKey] = now;
              updatedMetadata[kArchivedByIdKey] =
                  _organismRecordRepository.user.id;
              updatedMetadata[kArchivedReasonTypeKey] =
                  kArchiveReasonTypeMortality;
              updatedMetadata[kArchivedReasonIdKey] =
                  PopulationLossReason.mortality.id;
            }

            var updatedRecord = record.copyWith(
              metadata: updatedMetadata,
              updatedAt: now,
              updatedById: _organismRecordRepository.user.id,
            );
            if (shouldArchiveForZero) {
              updatedRecord = updatedRecord.copyWith(
                measurement: record.measurement.copyWith(value: 0),
              );
            }

            await _organismRecordRepository.updateRecord(updatedRecord);
            await _snapshotService.createAfterSnapshot(
              record: updatedRecord,
              eventId: event.id,
            );
          }

          // Propagate the event to parent nodes
          await _propagateMonitoringEvent(node, event, data);

          // Update deliverable progress (best-effort, non-blocking)
          final callback = _onMonitoringEventCallback;
          if (callback != null) {
            unawaited(
              callback(
                event.id,
                monitoringEvent: event,
                siteId: data.siteId,
                organizationId: record.organizationId,
              ),
            );
          }

          return event;
        } on FeatureDisabledError {
          rethrow;
        } on ArgumentError {
          // Rethrow validation errors for caller handling
          rethrow;
        } catch (e, stackTrace) {
          LoggingService.instance.error(
            'Failed to create monitoring event',
            e,
            stackTrace,
          );
          return null;
        }
      },
      metadata: {
        'organismId': data.organismId,
        if (data.siteId != null) 'siteId': data.siteId,
        'hasHealthStatusChange': data.newHealthStatus != null,
      },
    );
  }

  /// Propagate a monitoring event to parent nodes for activity feeds.
  Future<void> _propagateMonitoringEvent(
    GraphNode node,
    MonitoringEventRecord event,
    OrganismMonitoringData data,
  ) async {
    return PerformanceAnalyzer.measure(
      'MonitoringService.propagateMonitoringEvent',
      () async {
        try {
          final hasHealthChange = data.newHealthStatus != null;
          final activityType = hasHealthChange
              ? 'Health Status Update'
              : 'Monitoring';
          final description = hasHealthChange
              ? 'Health status changed from ${data.oldHealthStatus.name} '
                    'to ${data.newHealthStatus!.name}'
              : 'Monitoring data recorded';

          final newStatus = (data.newHealthStatus ?? data.oldHealthStatus).id;
          await _eventPropagationService.propagateToParents(
            sourceEvent: event,
            sourceNode: node,
            activityType: activityType,
            description: description,
            parameters: {
              'healthIssueTypeId': data.healthIssueTypeId,
              'oldHealthStatus': data.oldHealthStatus.id,
              'newHealthStatus': newStatus,
            },
          );
        } catch (e, stackTrace) {
          LoggingService.instance.error(
            'Failed to propagate monitoring event',
            e,
            stackTrace,
          );
        }
      },
      metadata: {
        'eventId': event.id,
        'recordId': event.recordId,
        if (data.siteId != null) 'siteId': data.siteId,
        'hasHealthStatusChange': data.newHealthStatus != null,
      },
    );
  }

  /// Get monitoring events for a specific organism.
  Future<List<MonitoringEventRecord>> getMonitoringEventsForOrganism(
    String organismId,
  ) {
    _ensureFeatureEnabled();
    return _monitoringEventRepository.getMonitoringEventsForOrganism(
      organismId,
    );
  }

  /// Get monitoring events for a specific site
  Future<List<MonitoringEventRecord>> getMonitoringEventsForSite(
    String siteId,
  ) {
    _ensureFeatureEnabled();
    return _monitoringEventRepository.getMonitoringEventsForSite(siteId);
  }

  /// Get monitoring events for a date range
  Future<List<MonitoringEventRecord>> getMonitoringEventsForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    _ensureFeatureEnabled();
    return _monitoringEventRepository.getMonitoringEventsForDateRange(
      startDate,
      endDate,
    );
  }

  /// Update an existing monitoring event
  Future<MonitoringEventRecord?> updateMonitoringEvent({
    required String eventId,
    String? newHealthStatus,
    String? comment,
    String? imageUrl,
    double? percentCover,
    double? percentBleaching,
    double? percentDisease,
    Map<String, dynamic>? measurements,
  }) async {
    _ensureFeatureEnabled();
    try {
      return await _monitoringEventRepository.updateMonitoringEvent(
        eventId: eventId,
        newHealthStatus: newHealthStatus,
        comment: comment,
        imageUrl: imageUrl,
        percentCover: percentCover,
        percentBleaching: percentBleaching,
        percentDisease: percentDisease,
        measurements: measurements,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to update monitoring event',
        e,
        stackTrace,
      );
      return null;
    }
  }

  /// Converts repository records to the UI-facing [OrganismMonitoringData] format.
  List<OrganismMonitoringData> convertEventsToMonitoringData(
    List<MonitoringEventRecord> events,
    Map<String, String> recordNames,
    Map<String, String> speciesNames,
  ) {
    return events.map((event) {
      final recordName = recordNames[event.recordId] ?? 'Unknown Organism';
      final speciesName = speciesNames[event.recordId] ?? 'Unknown Species';

      return OrganismMonitoringData(
        organismId: event.recordId,
        recordName: recordName,
        speciesId: event.recordModelType.name,
        speciesName: speciesName,
        genetId: '', // Would need to be populated from organism data.
        siteId: event.siteId,
        siteName: null,
        oldHealthStatus: event.oldHealthStatusEnum ?? HealthStatus.healthy,
        newHealthStatus: event.newHealthStatusEnum,
        healthIssueTypeId: event.healthIssueTypeId,
        percentCover: event.percentCover,
        percentBleaching: event.percentBleaching,
        percentDisease: event.percentDisease,
        measurements: event.measurements,
        imageUrl: event.imageUrl,
        comment: event.comment,
        monitoringDate:
            event.monitoringDate ??
            DateTimeConverter.fromIso8601String(event.createdAt) ??
            DateTime.now(),
        createTask: event.createTask,
        tagId: event.measurements?['tagId'] ?? event.measurements?['tag_id'],
        physicalForm:
            (event.measurements?['physicalFormId'] ??
                    event.measurements?['physical_form_id'])
                ?.toString(),
        morphologyId: CoralMorphologyX.tryParse(
          (event.measurements?['morphologyId'] ??
                  event.measurements?['morphology_id'])
              ?.toString(),
        )?.id,
      );
    }).toList();
  }

  MonitoringEntry _buildMonitoringEntry(OrganismMonitoringData data) {
    final measurements = <String, dynamic>{...?data.measurements};
    if (data.recordName.trim().isNotEmpty) {
      measurements['recordName'] = data.recordName;
    }
    if (data.recordUrlPath != null && data.recordUrlPath!.trim().isNotEmpty) {
      measurements['recordUrlPath'] = data.recordUrlPath;
    }
    if (data.tagId?.isNotEmpty ?? false) {
      measurements['tagId'] = data.tagId;
    }
    if (data.physicalForm != null) {
      measurements['physicalFormId'] = data.physicalForm;
    }
    if (data.morphologyId != null) {
      measurements['morphologyId'] = data.morphologyId;
    }

    return MonitoringEntry(
      genetId: data.genetId.isNotEmpty ? data.genetId : data.organismId,
      tagId: data.tagId,
      physicalForm: data.physicalForm,
      morphologyId: data.morphologyId,
      notes: data.comment,
      healthStatus: (data.newHealthStatus ?? data.oldHealthStatus).id,
      percentCover: data.percentCover,
      percentBleaching: data.percentBleaching,
      percentDisease: data.percentDisease,
      measurements: measurements.isEmpty ? null : measurements,
    );
  }

  double? _monitoringCount(Map<String, dynamic>? measurements) {
    if (measurements == null || measurements.isEmpty) return null;
    const keys = [
      'count',
      'quantity',
      'quantity_value',
      'quantityValue',
      'measurement_value',
      'measurementValue',
    ];
    for (final key in keys) {
      final raw = measurements[key];
      if (raw is num) return raw.toDouble();
      if (raw is String) {
        final parsed = double.tryParse(raw.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  void _ensureFeatureEnabled() {
    if (_featureEnabled) {
      return;
    }
    throw FeatureDisabledError(
      featureKey: featureKey,
      message: 'Monitoring workflows coming soon.',
      recoverySuggestion:
          'Upgrade to capture monitoring observations and imagery.',
    );
  }
}
