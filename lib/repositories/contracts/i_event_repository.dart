// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/models.dart';

/// Interface contract for EventRepository.
///
/// This mirrors the concrete repository API used in production so concrete
/// repositories can implement it and tests can mock it.
abstract class IEventRepository {
  /// Stream all events for the organization.
  Stream<List<Event>> get streamAll;

  /// Stream events for a specific URL path.
  Stream<List<Event>> streamEventsForUrlPath(
    String urlPath, {
    String? recordId,
    bool shallow = false,
    int limit = 100,
  });

  /// Stream events for a URL path using client-side filtering.
  Stream<List<Event>> streamRecordsForUrlPath(
    String urlPath, {
    bool shallow = false,
  });

  /// Stream a single event for a specific URL path.
  Stream<Event?> streamRecordForUrlPath(String urlPath);

  /// Fetch historical events with pagination.
  Future<List<Event>> fetchHistoricalEvents({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 1000,
    DocumentSnapshot? startAfter,
  });

  /// Fetch historical events for a URL path with pagination.
  Future<PaginatedEvents> fetchHistoricalEventsForUrlPath({
    required String urlPath,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 100,
    DocumentSnapshot? startAfter,
  });

  /// Stream recent events within a configurable time window.
  Stream<List<Event>> streamRecentEvents({
    Duration window = const Duration(days: 30),
    int? limit = 10000,
  });

  /// Get all events.
  Future<List<Event>> getAll();

  /// Get a single event by ID.
  Future<Event?> getRecordForId(String id);

  /// Get all events for a URL path.
  Future<List<Event>> getRecordsForUrlPath(
    String urlPath, {
    bool shallow = false,
  });

  /// Update an existing event.
  Future<void> updateRecord(Event record, {WriteBatch? batch});

  /// Delete an event.
  Future<void> deleteRecord(Event record, {WriteBatch? batch});

  /// Run a block with a timestamp override.
  Future<T> withTimestampOverride<T>(
    DateTime timestamp,
    Future<T> Function() action,
  );

  /// Move events when a record moves.
  Future<void> moveEvents({
    required List<Event> events,
    required InventoryRecord fromRecord,
    required InventoryRecord toRecord,
    required Transaction transaction,
  });

  /// Create a create event for a record.
  Future<CreateEvent> addCreateEvent<T extends InventoryRecord>(
    T record,
    InventoryRecord parent,
    WriteBatch batch, {
    EventBaseParams base = const EventBaseParams(),
  });

  /// Create a move-in event.
  Future<MoveInEvent> createMoveInEvent(
    InventoryRecord movedRecord,
    InventoryRecord fromParent,
    InventoryRecord toParent,
    Transaction transaction, {
    int? quantity,
    String? moveReason,
    EventBaseParams base = const EventBaseParams(),
  });

  /// Create a move-out event.
  Future<MoveOutEvent> createMoveOutEvent(
    InventoryRecord record,
    InventoryRecord fromParent,
    InventoryRecord toParent,
    Transaction transaction, {
    int? quantity,
    String? moveReason,
    EventBaseParams base = const EventBaseParams(),
  });

  /// Create an observation event.
  Future<ObservationEvent> createObservationEvent({
    required InventoryRecord forRecord,
    String? comment,
    String? imageUrl,
    String? oldHealthStatus,
    String? newHealthStatus,
    String? healthIssueTypeId,
    bool createTask = false,
    DateTime? createdAt,
    WriteBatch? batch,
  });

  /// Create a monitoring event.
  Future<MonitoringEventRecord> createMonitoringEvent({
    required InventoryRecord forRecord,
    String? comment,
    String? imageUrl,
    String? oldHealthStatus,
    String? newHealthStatus,
    String? healthIssueTypeId,
    double? percentCover,
    double? percentBleaching,
    double? percentDisease,
    Map<String, dynamic>? measurements,
    String? siteId,
    DateTime? monitoringDate,
    List<String>? organismIds,
    List<String>? coralIds,
    bool createTask = false,
    OutplantGeometry? outplantGeometry,
    List<MonitoringEntry> entries = const [],
    int? totalCount,
    EventBaseParams base = const EventBaseParams(),
  });

  /// Create a propagation event.
  Future<PropagationEvent> createPropagationEvent({
    required Site site,
    required List<OrganismRecord> inputOrganisms,
    required List<OrganismRecord> outputOrganisms,
    int? inputQuantityOverride,
    int? outputQuantityOverride,
    Map<String, dynamic>? additionalMetadata,
    EventBaseParams base = const EventBaseParams(),
  });

  /// Create an outplant event.
  ///
  /// [missionId] optionally links this event to a mission that initiated it.
  Future<OutplantEvent> createOutplantEvent({
    required Site site,
    required String name,
    required List<OutplantAllocation> allocations,
    String? comment,
    double? percentCover,
    double? percentBleaching,
    double? percentDisease,
    String? healthStatus,
    OutplantGeometry? geometry,
    EventPermitMetadata permitMetadata = const EventPermitMetadata.empty(),
    String? deliverableId,
    String? funderId,
    String? attachmentMethodId,
    String? missionId,
    WriteBatch? batch,
  });

  /// Update an outplant event's geometry.
  Future<OutplantEvent> updateOutplantGeometry({
    required OutplantEvent event,
    OutplantGeometry? geometry,
    bool clearGeometry = false,
    WriteBatch? batch,
  });

  /// Update an event's photo URLs and optionally its primary imageUrl.
  ///
  /// Used by offline sync to attach photos after they've been uploaded
  /// to Firebase Storage.
  ///
  /// If [imageUrl] is provided, also updates the event's primary image URL.
  /// This is useful when syncing offline-captured photos where the initial
  /// imageUrl points to a local storage path.
  Future<void> updateEventPhotos({
    required String eventId,
    required List<String> photoUrls,
    String? imageUrl,
    WriteBatch? batch,
  });

  /// Ensure an outplant event name is unique within the organization.
  Future<String> ensureUniqueOutplantName(String baseName);

  /// Create an event record.
  Future<Event> createEvent(Event event, {WriteBatch? batch});

  /// Create a correction event.
  Future<CorrectionEvent> createCorrectionEvent({
    required Event originalEvent,
    required Event correctedEvent,
    required EventType correctionType,
    String? notes,
  });

  /// Create a correction event for an inventory record update.
  Future<CorrectionEvent> createInventoryRecordCorrectionEvent({
    required InventoryRecord originalRecord,
    required InventoryRecord updatedRecord,
    required Map<String, dynamic> changes,
    String? notes,
  });

  /// Fetch propagation-ready events for a genet within a site.
  Future<List<PropagationReadyStatus>> getPropagationReadyEvents({
    required String genetId,
    required String siteUrlPath,
  });

  /// Fetch outplant events.
  Future<List<OutplantEvent>> fetchOutplantEvents({
    DateTime? start,
    DateTime? end,
    String? siteId,
    int? limit,
  });

  /// Fetch events by event type.
  Future<List<T>> fetchEventsByType<T extends Event>({
    required String eventTypeId,
    DateTime? start,
    DateTime? end,
    int? limit,
  });

  /// Stream outplant events.
  Stream<List<OutplantEvent>> streamOutplantEvents({
    String? siteId,
    int limit = 50,
  });

  /// Fetch monitoring events.
  Future<List<MonitoringEventRecord>> fetchMonitoringEvents({
    DateTime? start,
    DateTime? end,
    String? siteId,
    bool attachOutplantGeometry = false,
  });

  /// Fetch observation events.
  Future<List<ObservationEvent>> fetchObservationEvents({
    String? recordId,
    ModelType? recordModelType,
    String? healthIssueTypeId,
    DateTime? start,
    DateTime? end,
    int? limit,
  });

  /// Stream events for a single organism record.
  Stream<List<Event>> watchOrganismRecordEvents({
    required String recordId,
    int limit = 100,
  });

  /// Fetch events created by a specific user.
  Future<List<Event>> getEventsForUser({
    required String userId,
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Fetch events created by a specific user with pagination support.
  ///
  /// Returns a page of events ordered by createdAt DESC with a cursor for the
  /// next page.
  Future<PaginatedEvents> getEventsForUserPage({
    required String userId,
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
    DocumentSnapshot? startAfter,
  });

  /// Count events created by a specific user.
  ///
  /// Returns the total count of events where [createdById] matches [userId].
  Future<int> countEventsForUser({required String userId});

  /// Stream events created by a specific user.
  Stream<List<Event>> streamEventsForUser({
    required String userId,
    int limit = 50,
  });

  /// Stream pending/shipped transfers addressed to the organization.
  Stream<List<TransferEvent>> streamPendingTransfers({
    List<String>? eventTypeIds,
  });

  /// Stream events linked to a specific mission.
  ///
  /// Returns events where [missionId] matches the given mission ID.
  /// Results are ordered by creation date (newest first) and limited to [limit].
  Stream<List<Event>> watchEventsForMission({
    required String missionId,
    int limit = 100,
  });

  /// Fetch events linked to a specific mission.
  ///
  /// Returns events where [missionId] matches the given mission ID.
  /// Results are ordered by creation date (newest first) and limited to [limit].
  Future<List<Event>> getEventsForMission({
    required String missionId,
    int limit = 100,
  });

  /// Create a life stage transition event.
  Future<LifeStageTransitionEvent> createLifeStageTransitionEvent({
    required String recordId,
    required String recordUrlPath,
    required String recordInternalPath,
    required OrganismRecord snapshot,
    required LifeStage oldLifeStage,
    required LifeStage newLifeStage,
    String? oldSubtype,
    String? newSubtype,
    String? transitionReason,
    Map<String, dynamic>? metadata,
    WriteBatch? batch,
  });

  /// Create a physical form change event.
  Future<PhysicalFormChangeEvent> createPhysicalFormChangeEvent({
    required String recordId,
    required String recordUrlPath,
    required String recordInternalPath,
    required OrganismRecord snapshot,
    String? oldFormId,
    String? newFormId,
    Map<String, dynamic>? metadata,
    WriteBatch? batch,
  });

  /// Create a size change event.
  Future<SizeChangeEvent> createSizeChangeEvent({
    required String recordId,
    required String recordUrlPath,
    required String recordInternalPath,
    required OrganismRecord snapshot,
    required SizeSpec oldSize,
    required SizeSpec newSize,
    Map<String, dynamic>? metadata,
    WriteBatch? batch,
  });

  /// Create a quantity change event.
  Future<QuantityChangeEvent> createQuantityChangeEvent({
    required String recordId,
    required String recordUrlPath,
    required String recordInternalPath,
    required OrganismRecord snapshot,
    required PopulationMeasurement oldMeasurement,
    required PopulationMeasurement newMeasurement,
    Map<String, dynamic>? metadata,
    WriteBatch? batch,
  });

  /// Enrich an event with organism metadata.
  T withOrganismMetadata<T extends Event>(
    T event, {
    Map<String, dynamic>? additionalMetadata,
  });
}
