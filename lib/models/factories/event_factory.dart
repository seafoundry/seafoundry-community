// @tier: community
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Factory for creating Event instances from JSON data.
///
/// **Common Issues:**
/// 1. Missing `modelType: 'event'` - Required for RecordFactory to route to EventFactory
/// 2. Missing `eventTypeId` - Required to determine specific event type
/// 3. Using `snapshot` instead of `snapshotData` - Inventory events expect `snapshotData`
/// 4. Wrong `recordModelType` - Use 'organismRecord' not 'coral' for organism events
class EventFactory {
  /// Parse JSON into an Event.
  ///
  /// **Required Fields:**
  /// - `eventTypeId`: String identifying the event type (e.g., 'event_create', 'event_move_in')
  /// - `id`: String identifier for the event
  ///
  /// **For Inventory Events (moves, frags, population changes):**
  /// - `snapshotData`: Map containing the organism/record snapshot (NOT `snapshot`)
  /// - `recordModelType`: 'organismRecord' for organism-related events
  ///
  /// **Common eventTypeId values:**
  /// - `event_create`, `event_move_in`, `event_move_out`, `event_propagation`
  /// - `event_population_gain`, `event_population_loss`
  /// - `event_observation`, `outplant_event`
  static Event eventFromJson(Map<String, dynamic> json) {
    final normalizedJson = _normalizeEventJson(json);
    final eventTypeId = normalizedJson['eventTypeId']?.toString();

    // Validate required fields with helpful error messages
    if (eventTypeId == null || eventTypeId.isEmpty) {
      LoggingService.instance.error(
        'EventFactory: Missing required field "eventTypeId".\n'
        '  Available keys: ${json.keys.toList()}\n'
        '  id: ${json['id']}\n'
        '  Hint: Every event must have an eventTypeId like "event_create", "event_move_in", etc.',
      );
      return Event.fromJson(normalizedJson);
    }

    // Validate snapshotData for inventory events
    final inventoryEventTypes = {
      'event_create',
      'event_move_in',
      'event_move_out',
      'event_propagation',
      'event_population_gain',
      'event_population_loss',
      'event_split',
      'event_merge',
    };
    if (inventoryEventTypes.contains(eventTypeId)) {
      final snapshotData = normalizedJson['snapshotData'];
      if (snapshotData == null) {
        // Check if they used 'snapshot' instead of 'snapshotData'
        if (normalizedJson.containsKey('snapshot')) {
          LoggingService.instance.warning(
            'EventFactory: Event ${json['id']} uses deprecated "snapshot" field. '
            'Rename to "snapshotData" for inventory events.',
          );
        } else {
          LoggingService.instance.warning(
            'EventFactory: Inventory event ${json['id']} ($eventTypeId) missing "snapshotData" field. '
            'This may cause null errors when displaying the event.',
          );
        }
      } else if (snapshotData is! Map) {
        LoggingService.instance.error(
          'EventFactory: Event ${json['id']} has invalid "snapshotData" - expected Map, got ${snapshotData.runtimeType}',
        );
      }
    }

    // Handle special event types by string ID first
    switch (eventTypeId) {
      case 'event_activity':
        return ActivityEvent.fromJson(normalizedJson);
      case 'event_transfer':
      case 'event_loan':
        return TransferEvent.fromJson(normalizedJson);
      case HusbandryEventType.feedingId:
        return FeedingEvent.fromJson(normalizedJson);
      case HusbandryEventType.waterQualityTestId:
        return WaterQualityTestEvent.fromJson(normalizedJson);
      case HusbandryEventType.cleaningId:
        return CleaningEvent.fromJson(normalizedJson);
      case HusbandryEventType.treatmentId:
        return TreatmentEvent.fromJson(normalizedJson);
      case HusbandryEventType.environmentalAdjustmentId:
        return EnvironmentalAdjustmentEvent.fromJson(normalizedJson);
      case HusbandryEventType.structureMaintenanceId:
        return StructureMaintenanceEvent.fromJson(normalizedJson);
      case HusbandryEventType.acquireOrthomosaicId:
      case HusbandryEventType.sitePrepId:
        return OutplantActionEvent.fromJson(normalizedJson);
      case HusbandryEventType.ecologicalSurveyId:
        return MonitoringEventRecord.fromJson(normalizedJson);
      case HusbandryEventType.husbandryLogId:
        return HusbandryLogEvent.fromJson(normalizedJson);
      case GeneBankEventType.auditId:
        return GeneBankAuditEvent.fromJson(normalizedJson);
      case GeneBankEventType.temperatureMonitoringId:
        return GeneBankTemperatureMonitoringEvent.fromJson(normalizedJson);
      case GeneBankEventType.viabilityTestId:
        return GeneBankViabilityTestEvent.fromJson(normalizedJson);
      case 'event_disease_observation':
        return DiseaseObservationEvent.fromJson(normalizedJson);
      case 'event_biofouling_observation':
        return BiofoulingObservationEvent.fromJson(normalizedJson);
      case 'event_pest_observation':
        return PestObservationEvent.fromJson(normalizedJson);
      case 'event_thermal_stress_observation':
        return ThermalStressObservationEvent.fromJson(normalizedJson);
      case 'event_population_gain':
        return PopulationGainEvent.fromJson(normalizedJson);
      case var id when id == EventType.maintenanceRequiredObservation.id:
        return MaintenanceRequiredObservationEvent.fromJson(normalizedJson);
      case 'event_discoloration_observation':
        return DiscolorationObservationEvent.fromJson(normalizedJson);
      case 'outplant_event':
      case 'event_outplant':
        return OutplantEvent.fromJson(normalizedJson);
      case InventoryEventType.splitId:
        return SplitEvent.fromJson(normalizedJson);
      case InventoryEventType.mergeId:
        return MergeEvent.fromJson(normalizedJson);
      case var id when id == EventType.inventoryRecordCorrection.id:
      case var id when id == EventType.inventoryEventCorrection.id:
      case var id when id == EventType.observationCorrection.id:
      case var id when id == EventType.geneticRecordCorrection.id:
        return CorrectionEvent.fromJson(normalizedJson);
    }

    EventType? eventType = EventType.builtins[eventTypeId];
    if (eventType == null) {
      LoggingService.instance.error('Unknown event type: $eventTypeId\n$json');
      eventType = EventType.unknown;
    }
    switch (eventType) {
      case EventType.unknown:
        return Event.fromJson(normalizedJson);
      case EventType.moveIn:
        return MoveInEvent.fromJson(normalizedJson);
      case EventType.moveOut:
        return MoveOutEvent.fromJson(normalizedJson);
      case EventType.propagation:
        return PropagationEvent.fromJson(normalizedJson);
      case EventType.outplant:
        return OutplantEvent.fromJson(normalizedJson);
      case EventType.task:
        return TaskEvent.fromJson(normalizedJson);
      case EventType.comment:
        return Event.fromJson(normalizedJson);
      case StatusEventType.propagationReady:
        return PropagationReadyStatus.fromJson(normalizedJson);
      case StatusEventType.recentPropagation:
        return RecentPropagationStatus.fromJson(normalizedJson);
      case EventType.spawn:
        return SpawnEvent.fromJson(normalizedJson);
      case EventType.cross:
        return CrossEvent.fromJson(normalizedJson);
      case EventType.update:
        return UpdateEvent.fromJson(normalizedJson);
      case EventType.delete:
        return DeletionEvent.fromJson(normalizedJson);
      case EventType.settle:
        return SettleEvent.fromJson(normalizedJson);
      case EventType.create:
        return CreateEvent.fromJson(normalizedJson);
      case EventType.observation:
        // Check if this is a monitoring event (has coralIds/organismIds or monitoringDate)
        if (normalizedJson['coralIds'] != null ||
            normalizedJson['organismIds'] != null ||
            normalizedJson['monitoringDate'] != null) {
          return MonitoringEventRecord.fromJson(normalizedJson);
        }
        return ObservationEvent.fromJson(normalizedJson);
      case InventoryEventType.populationGain:
        return PopulationGainEvent.fromJson(normalizedJson);
      case InventoryEventType.populationLoss:
        // Check for outplant mortality (has outplantLossReasonId or lossReasonId is an OutplantLossReason)
        if (normalizedJson['outplantLossReasonId'] != null ||
            OutplantLossReason.builtins.containsKey(
              normalizedJson['lossReasonId'],
            )) {
          return OutplantMortalityEvent.fromJson(normalizedJson);
        }
        // Check for nursery mortality (has mortalityReasonId or lossReasonId is mortality)
        if (normalizedJson['mortalityReasonId'] != null ||
            normalizedJson['lossReasonId'] ==
                PopulationLossReason.mortality.id) {
          return MortalityEvent.fromJson(normalizedJson);
        }
        return PopulationLossEvent.fromJson(normalizedJson);
      case InventoryEventType.lifeStageTransition:
        return LifeStageTransitionEvent.fromJson(normalizedJson);
      case InventoryEventType.physicalFormChange:
        return PhysicalFormChangeEvent.fromJson(normalizedJson);
      case InventoryEventType.sizeChange:
        return SizeChangeEvent.fromJson(normalizedJson);
      case InventoryEventType.quantityChange:
        return QuantityChangeEvent.fromJson(normalizedJson);
      case LoanEventType.loan:
        return TransferEvent.fromJson(normalizedJson);
      case HusbandryEventType.cleaning:
        return CleaningEvent.fromJson(normalizedJson);
      case HusbandryEventType.feeding:
        return FeedingEvent.fromJson(normalizedJson);
      case HusbandryEventType.treatment:
        return TreatmentEvent.fromJson(normalizedJson);
      case HusbandryEventType.environmentalAdjustment:
        return EnvironmentalAdjustmentEvent.fromJson(normalizedJson);
      case HusbandryEventType.structureMaintenance:
        return StructureMaintenanceEvent.fromJson(normalizedJson);
      case HusbandryEventType.waterQualityTest:
        return WaterQualityTestEvent.fromJson(normalizedJson);
      case HusbandryEventType.acquireOrthomosaic:
      case HusbandryEventType.sitePrep:
        return OutplantActionEvent.fromJson(normalizedJson);
      case CoralSizeEventType.growth:
      case CoralSizeEventType.tissueLoss:
      case CoralSizeEventType.sizeAdded:
        return CoralSizeEvent.fromJson(normalizedJson);
      case EventType.genetModification:
        return GenetModificationEvent.fromJson(normalizedJson);
      case EventType.inventoryRecordCorrection:
      case EventType.inventoryEventCorrection:
      case EventType.observationCorrection:
      case EventType.geneticRecordCorrection:
        return CorrectionEvent.fromJson(normalizedJson);
      default:
        // Community build: return base Event for unrecognized types
        return Event.fromJson(normalizedJson);
    }
  }

  static Event incompleteEventFromJson(Map<String, dynamic> json) {
    final normalizedJson = _normalizeEventJson(json);
    final eventTypeId = normalizedJson['eventTypeId']?.toString();

    // Handle new event types by string ID first
    switch (eventTypeId) {
      // Transfer Events
      case 'event_transfer':
      case 'event_loan':
        return TransferEvent.incomplete(json: normalizedJson);
      // Activity Events
      case 'event_activity':
        return ActivityEvent.partial(json: normalizedJson);
      case 'outplant_event':
      case 'event_outplant':
        return OutplantEvent.partial(json: normalizedJson);
      case HusbandryEventType.feedingId:
        return FeedingEvent.partial(json: normalizedJson);
      case HusbandryEventType.waterQualityTestId:
        return WaterQualityTestEvent.partial(json: normalizedJson);
      case HusbandryEventType.cleaningId:
        return CleaningEvent.partial(json: normalizedJson);
      case HusbandryEventType.treatmentId:
        return TreatmentEvent.partial(json: normalizedJson);
      case HusbandryEventType.environmentalAdjustmentId:
        return EnvironmentalAdjustmentEvent.partial(json: normalizedJson);
      case HusbandryEventType.structureMaintenanceId:
        return StructureMaintenanceEvent.partial(json: normalizedJson);
      case HusbandryEventType.acquireOrthomosaicId:
      case HusbandryEventType.sitePrepId:
        return OutplantActionEvent.partial(json: normalizedJson);
      case HusbandryEventType.ecologicalSurveyId:
        return MonitoringEventRecord.partial(json: normalizedJson);
      case HusbandryEventType.husbandryLogId:
        return HusbandryLogEvent.partial(json: normalizedJson);
      case GeneBankEventType.auditId:
        return GeneBankAuditEvent.partial(json: normalizedJson);
      case GeneBankEventType.temperatureMonitoringId:
        return GeneBankTemperatureMonitoringEvent.partial(json: normalizedJson);
      case GeneBankEventType.viabilityTestId:
        return GeneBankViabilityTestEvent.partial(json: normalizedJson);
      case 'event_disease_observation':
        return DiseaseObservationEvent.partial(json: normalizedJson);
      case 'event_biofouling_observation':
        return BiofoulingObservationEvent.partial(json: normalizedJson);
      case 'event_pest_observation':
        return PestObservationEvent.partial(json: normalizedJson);
      case 'event_thermal_stress_observation':
        return ThermalStressObservationEvent.partial(json: normalizedJson);
      case var id when id == EventType.maintenanceRequiredObservation.id:
        return MaintenanceRequiredObservationEvent.partial(
          json: normalizedJson,
        );
      case 'event_discoloration_observation':
        return DiscolorationObservationEvent.partial(json: normalizedJson);
      case var id when id == EventType.inventoryRecordCorrection.id:
      case var id when id == EventType.inventoryEventCorrection.id:
      case var id when id == EventType.observationCorrection.id:
      case var id when id == EventType.geneticRecordCorrection.id:
        return CorrectionEvent.fromJson(normalizedJson);
    }

    EventType? eventType = EventType.builtins[eventTypeId];
    if (eventType == null) {
      LoggingService.instance.error(
        'Unknown incomplete event type: $eventTypeId\n$json',
      );
      eventType = EventType.create;
    }
    switch (eventType) {
      case EventType.create:
        return CreateEvent.partial(json: normalizedJson);
      case EventType.outplant:
        return OutplantEvent.partial(json: normalizedJson);
      case EventType.observation:
        // Check if this is a monitoring event (has coralIds/organismIds or monitoringDate)
        if (normalizedJson['coralIds'] != null ||
            normalizedJson['organismIds'] != null ||
            normalizedJson['monitoringDate'] != null) {
          return MonitoringEventRecord.partial(json: normalizedJson);
        }
        return ObservationEvent.partial(json: normalizedJson);
      case EventType.task:
        return TaskEvent.partial(json: normalizedJson);
      case EventType.comment:
        return Event.partial(json: normalizedJson);
      case EventType.moveIn:
        return MoveInEvent.partial(json: normalizedJson);
      case EventType.moveOut:
        return MoveOutEvent.partial(json: normalizedJson);
      case EventType.propagation:
        return PropagationEvent.partial(json: normalizedJson);
      case StatusEventType.propagationReady:
      case StatusEventType.recentPropagation:
        return StatusEvent.partial(json: normalizedJson);
      case EventType.spawn:
        return SpawnEvent.partial(json: normalizedJson);
      case EventType.cross:
        return CrossEvent.partial(json: normalizedJson);
      case EventType.update:
        return UpdateEvent.partial(json: normalizedJson);
      case EventType.delete:
        return DeletionEvent.partial(json: normalizedJson);
      case EventType.settle:
        return SettleEvent.partial(json: normalizedJson);
      case InventoryEventType.populationGain:
        return PopulationGainEvent.fromJson(normalizedJson);
      case InventoryEventType.populationLoss:
        return PopulationLossEvent.fromJson(normalizedJson);
      case InventoryEventType.lifeStageTransition:
        return LifeStageTransitionEvent.fromJson(normalizedJson);
      case InventoryEventType.physicalFormChange:
        return PhysicalFormChangeEvent.fromJson(normalizedJson);
      case InventoryEventType.sizeChange:
        return SizeChangeEvent.fromJson(normalizedJson);
      case InventoryEventType.quantityChange:
        return QuantityChangeEvent.fromJson(normalizedJson);
      case InventoryEventType.split:
        return SplitEvent.fromJson(normalizedJson);
      case InventoryEventType.merge:
        return MergeEvent.fromJson(normalizedJson);
      case LoanEventType.loan:
        return TransferEvent.incomplete(json: normalizedJson);
      case HusbandryEventType.cleaning:
        return CleaningEvent.partial(json: normalizedJson);
      case HusbandryEventType.feeding:
        return FeedingEvent.partial(json: normalizedJson);
      case HusbandryEventType.treatment:
        return TreatmentEvent.partial(json: normalizedJson);
      case HusbandryEventType.environmentalAdjustment:
        return EnvironmentalAdjustmentEvent.partial(json: normalizedJson);
      case HusbandryEventType.structureMaintenance:
        return StructureMaintenanceEvent.partial(json: normalizedJson);
      case HusbandryEventType.waterQualityTest:
        return WaterQualityTestEvent.partial(json: normalizedJson);
      case HusbandryEventType.acquireOrthomosaic:
      case HusbandryEventType.sitePrep:
        return OutplantActionEvent.partial(json: normalizedJson);
      case EventType.genetModification:
        return GenetModificationEvent.fromJson(normalizedJson);
      case EventType.inventoryRecordCorrection:
      case EventType.inventoryEventCorrection:
      case EventType.observationCorrection:
      case EventType.geneticRecordCorrection:
        return CorrectionEvent.fromJson(normalizedJson);
      default:
        // Community build: return partial Event for unrecognized types
        return Event.partial(json: normalizedJson);
    }
  }

  static Map<String, dynamic> _normalizeEventJson(Map<String, dynamic> json) {
    // First, deep normalize all nested maps to handle web Firestore's Map<dynamic, dynamic>
    final deepNormalized = deepNormalizeMap(json);

    final eventTypeId = deepNormalized['eventTypeId']?.toString();

    // Apply event-specific normalizations
    if (eventTypeId == 'event_death' || eventTypeId == 'death') {
      deepNormalized['eventTypeId'] = InventoryEventType.populationLoss.id;
      deepNormalized.putIfAbsent(
        'lossReasonId',
        () => PopulationLossReason.mortality.id,
      );
    } else if (eventTypeId == 'event_transfer') {
      deepNormalized['eventTypeId'] = LoanEventType.loan.id;
      deepNormalized['legacyEventTypeId'] = 'event_transfer';
    } else if (eventTypeId == 'event_frag') {
      deepNormalized['eventTypeId'] = 'event_propagation';
    } else if (eventTypeId == 'event_status_frag_ready') {
      deepNormalized['eventTypeId'] = 'event_status_propagation_ready';
    } else if (eventTypeId == 'event_status_recent_frag') {
      deepNormalized['eventTypeId'] = 'event_status_recent_propagation';
    }

    return deepNormalized;
  }
}
