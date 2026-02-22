// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/events/event.dart' show EventBaseParams;
import 'package:seafoundry_app/models/events/monitoring_event_record.dart';
import 'package:seafoundry_app/models/events/outplant_geometry.dart';
import 'package:seafoundry_app/models/monitoring/image_attachment.dart';
import 'package:seafoundry_app/models/monitoring/monitoring_entry.dart';
import 'package:seafoundry_app/models/records/inventory_record.dart';

/// Interface for monitoring event repositories
/// Enables easy mocking and testing while consolidating monitoring event operations
abstract class IMonitoringEventRepository {
  /// Create a monitoring event for an organism or site.
  ///
  /// [batch] Optional WriteBatch for atomic transactions. If provided,
  /// the event creation is added to the batch (caller must commit).
  /// If null, the event is written immediately.
  Future<MonitoringEventRecord> createMonitoringEvent({
    required InventoryRecord forRecord,
    String? oldHealthStatus,
    String? newHealthStatus,
    String? healthIssueTypeId,
    String? comment,
    String? imageUrl,
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
    List<ImageAttachment> imageAttachments = const [],
    EventBaseParams base = const EventBaseParams(),
    WriteBatch? batch,
  });

  /// Get all monitoring events for a specific site
  Future<List<MonitoringEventRecord>> getMonitoringEventsForSite(String siteId);

  /// Get all monitoring events for a specific organism.
  Future<List<MonitoringEventRecord>> getMonitoringEventsForOrganism(
    String organismId,
  );

  /// Get all monitoring events for a date range
  Future<List<MonitoringEventRecord>> getMonitoringEventsForDateRange(
    DateTime startDate,
    DateTime endDate,
  );

  /// Update an existing monitoring event
  Future<MonitoringEventRecord> updateMonitoringEvent({
    required String eventId,
    String? newHealthStatus,
    String? comment,
    String? imageUrl,
    double? percentCover,
    double? percentBleaching,
    double? percentDisease,
    Map<String, dynamic>? measurements,
  });

  /// Fetch all monitoring events for the organization
  Future<List<MonitoringEventRecord>> fetchMonitoringEvents({
    DateTime? start,
    DateTime? end,
    String? siteId,
    bool attachOutplantGeometry = false,
  });

  /// Stream all monitoring events for the organization
  ///
  /// Note: Named `streamMonitoringEvents` to avoid conflict with the `streamAll`
  /// getter inherited from BaseInventoryRecordRepository.
  Stream<List<MonitoringEventRecord>> streamMonitoringEvents({String? siteId});
}
