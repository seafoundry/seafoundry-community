// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/models.dart';
import '../../services/snapshot_service.dart';

/// Interface contract for OrganismRecordRepository.
///
/// This mirrors the concrete repository API used in production so concrete
/// repositories can implement it and tests can mock it.
abstract class IOrganismRecordRepository {
  /// Snapshot service for inventory state tracking.
  SnapshotService get snapshotService;

  /// Stream all organism records for the organization.
  Stream<List<OrganismRecord>> get streamAll;

  /// Stream organism records for a URL path using client-side filtering.
  Stream<List<OrganismRecord>> streamRecordsForUrlPath(
    String urlPath, {
    bool shallow = false,
  });

  /// Stream a single organism record for a URL path.
  Stream<OrganismRecord?> streamRecordForUrlPath(String urlPath);

  /// Get all organism records.
  Future<List<OrganismRecord>> getAll();

  /// Get a single organism record by ID.
  Future<OrganismRecord?> getRecordForId(String id);

  /// Get all organism records for a URL path.
  Future<List<OrganismRecord>> getRecordsForUrlPath(
    String urlPath, {
    bool shallow = false,
  });

  /// Create a new organism record.
  Future<OrganismRecord> createRecord(
    OrganismRecord partialRecord,
    GraphNodeRecord parent, {
    EventBaseParams base = const EventBaseParams(),
  });

  /// Move an organism record between parents.
  Future<OrganismRecord> moveRecord({
    required OrganismRecord record,
    required GraphNodeRecord fromParent,
    required GraphNodeRecord toParent,
    required Transaction transaction,
    PartialMoveSelection? partialSelection,
    String? moveReason,
    EventBaseParams base = const EventBaseParams(),
  });

  /// Update an existing organism record.
  Future<void> updateRecord(OrganismRecord record, {WriteBatch? batch});

  /// Delete an organism record.
  Future<void> deleteRecord(OrganismRecord record, {WriteBatch? batch});

  /// Stream organism records filtered by site (client-side filtering).
  Stream<List<OrganismRecord>> streamBySite(String siteId);

  /// Stream organism records filtered by group (client-side filtering).
  Stream<List<OrganismRecord>> streamByGroup(String groupId);

  /// Stream organism records filtered by organism type (client-side filtering).
  Stream<List<OrganismRecord>> streamByOrganism(OrganismKind kind);

  /// Stream organism records that are ready for propagation.
  Stream<List<OrganismRecord>> streamPropagatable();

  /// Stream organism records that are ready for outplanting.
  Stream<List<OrganismRecord>> streamReadyForOutplant();

  /// Query organism records by site using server-side filtering.
  Stream<List<OrganismRecord>> queryBySite(String siteId);

  /// Query organism records by group using server-side filtering.
  Stream<List<OrganismRecord>> queryByGroup(String groupId);

  /// Query organism records by organism kind using server-side filtering.
  Stream<List<OrganismRecord>> queryByOrganismKind(OrganismKind kind);

  /// Update record and emit appropriate events for all detected changes.
  Future<List<Event>> updateRecordWithEvents(
    OrganismRecord originalRecord,
    OrganismRecord updatedRecord, {
    Map<String, dynamic>? eventMetadata,
  });

  /// Update health status and create observation event.
  Future<OrganismHealthStatusPayload> updateHealthStatus(
    OrganismRecord organism,
    String newStatusId, {
    required String updatedById,
    String? comment,
    String? imageUrl,
  });

  /// Update health status without creating an observation event.
  Future<OrganismRecord> updateHealthStatusWithoutEvent(
    OrganismRecord organism,
    String newStatusId, {
    required String updatedById,
  });

  /// Update propagation ready status and create status event.
  Future<OrganismPropagationReadyPayload> updatePropagationReadyStatus(
    OrganismRecord organism,
    bool isReady, {
    String? comment,
  });

  /// Update propagation ready status without creating a status event.
  Future<OrganismRecord> updatePropagationReadyStatusWithoutEvent(
    OrganismRecord organism,
    bool isReady, {
    required String updatedById,
  });

  /// Update size and create size change event.
  Future<OrganismSizeChangePayload> updateSize(
    OrganismRecord organism,
    SizeSpec newSize, {
    String? comment,
  });

  /// Update population and create population change event.
  Future<OrganismPopulationChangePayload> updatePopulation(
    OrganismRecord organism,
    int newQuantity, {
    PopulationLossReason? lossReason,
    MortalityReason? mortalityReason,
    DiseaseType? diseaseType,
    PopulationGainReason? gainReason,
    String? comment,
    WriteBatch? batch,
  });

  /// Update measurement and emit quantity change event.
  Future<OrganismQuantityChangePayload> updateMeasurement({
    required OrganismRecord organism,
    required PopulationMeasurement newMeasurement,
    PopulationLossReason? lossReason,
    PopulationGainReason? gainReason,
    String? comment,
    bool archiveWhenZero = true,
  });

  /// Archive an organism record.
  Future<void> archiveOrganismRecord(String organismRecordId);

  /// Restore an archived organism record.
  Future<void> restoreOrganismRecord(String organismRecordId);

  /// Search organism records by query string with optional filters.
  Future<List<OrganismRecord>> search(
    String query, {
    OrganismKind? organismKind,
    LifeStage? lifeStage,
    String? physicalFormId,
    String? siteId,
    String? groupId,
    int limit = 50,
  });

  /// Get recent organism records ordered by updatedAt.
  Future<List<OrganismRecord>> getRecent({
    int limit = 5,
    OrganismKind? organismKind,
  });

  /// Get organisms by species ID.
  Future<List<OrganismRecord>> getBySpecies(
    String speciesId, {
    OrganismKind? organismKind,
  });

  /// Get organisms by genet provenance ID (PID- format).
  ///
  /// Rejects input that does not match provenance format.
  Future<List<OrganismRecord>> getByGenetProvenanceId(
    String provenanceId, {
    OrganismKind? organismKind,
  });

  /// Count organisms in a specific group.
  Future<int> countByGroup(String groupId);

  /// Update pending outplant status for an organism.
  Future<OrganismRecord> updatePendingOutplantStatus({
    required String organismId,
    required bool isPending,
    String? pendingBatchId,
    Map<String, dynamic>? pendingAllocation,
    WriteBatch? batch,
  });

  /// Get organisms allocated to a pending batch.
  Future<List<OrganismRecord>> getOrganismsForPendingBatch(String batchId);

  /// Update transfer lock status for an organism.
  Future<OrganismRecord> updateTransferLockStatus({
    required String organismId,
    required bool isLocked,
    String? pendingTransferId,
    int? lockedQuantity,
    WriteBatch? batch,
  });

  /// Update the localId for all organism records sharing the same genet.
  ///
  /// Used when user chooses "All records" in the LocalID edit scope dialog.
  /// Returns the number of records updated.
  Future<int> updateLocalIdGenetWide({
    required String genetId,
    required String newLocalId,
    required String updatedById,
  });
}
