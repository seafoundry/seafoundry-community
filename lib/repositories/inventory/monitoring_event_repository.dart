// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/events/event.dart' show EventBaseParams;
import 'package:seafoundry_app/models/events/monitoring_event_record.dart';
import 'package:seafoundry_app/models/events/outplant_geometry.dart';
import 'package:seafoundry_app/models/monitoring/image_attachment.dart';
import 'package:seafoundry_app/models/monitoring/monitoring_entry.dart';
import 'package:seafoundry_app/models/records/inventory_record.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/repositories/firebase_utils.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/utils/firestore_document_helpers.dart';
import 'package:seafoundry_app/repositories/inventory/i_monitoring_event_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/utils/date_time_converter.dart';

/// Repository for managing monitoring events
/// Follows main branch's architecture pattern for repositories
class MonitoringEventRepository extends EventRepository
    implements IMonitoringEventRepository {
  MonitoringEventRepository({
    required super.organization,
    required super.user,
    required super.firestore,
    super.organismContext,
    bool featureEnabled = true,
    bool imageryEnabled = true,
    this.featureKey = 'monitoring_dialog',
    this.imageryFeatureKey = 'imagery_attachments',
  })  : _featureEnabled = featureEnabled,
        _imageryEnabled = imageryEnabled;

  final bool _featureEnabled;
  final bool _imageryEnabled;
  final String featureKey;
  final String imageryFeatureKey;

  /// Create a monitoring event for an organism or site.
  /// Uses main branch's pattern for event creation
  ///
  /// [batch] Optional WriteBatch for atomic transactions. If provided,
  /// the event creation is added to the batch (caller must commit).
  /// If null, the event is written immediately.
  @override
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
  }) async {
    _ensureFeatureEnabled();
    _ensureImageryEnabled(
      imageUrl: imageUrl,
      attachments: imageAttachments,
    );
    try {
      final now = DateTimeConverter.nowAsIso8601String();
      final eventId = generateId(firestore: db);
      final eventSlug = await nextSlugForModelType(ModelType.event);

      var monitoringEvent = MonitoringEventRecord(
        id: eventId,
        createdById: user.id,
        createdAt: now,
        updatedAt: now,
        updatedById: user.id,
        organizationId: organization.id,
        recordId: forRecord.id,
        recordModelType: forRecord.modelType,
        urlPath: '${forRecord.urlPath}/$eventSlug',
        internalPath: '${forRecord.internalPath}/$eventId',
        slug: eventSlug,
        oldHealthStatus: oldHealthStatus,
        newHealthStatus: newHealthStatus,
        healthIssueTypeId: healthIssueTypeId,
        comment: comment,
        imageUrl: imageUrl,
        percentCover: percentCover,
        percentBleaching: percentBleaching,
        percentDisease: percentDisease,
        measurements: measurements,
        siteId: siteId,
        monitoringDate: monitoringDate,
        organismIds: organismIds ?? coralIds,
        createTask: createTask,
        outplantGeometry: outplantGeometry,
        entries: entries.isEmpty
            ? const []
            : List<MonitoringEntry>.from(entries, growable: false),
        totalCount: totalCount ?? entries.length,
        imageAttachments: imageAttachments,
        base: base,
      );

      monitoringEvent = withOrganismMetadata(monitoringEvent);
      await createEvent(monitoringEvent, batch: batch);
      LoggingService.instance.info('Created monitoring event: $eventId');

      return monitoringEvent;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to create monitoring event',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get all monitoring events for a specific site
  @override
  Future<List<MonitoringEventRecord>> getMonitoringEventsForSite(
    String siteId,
  ) async {
    _ensureFeatureEnabled();
    try {
      // Use organizationId filter to satisfy security rules
      // Avoid orderBy to prevent composite index requirements
      final querySnapshot = await organizationQuery(collectionRef)
          .where('eventTypeId', isEqualTo: EventType.observation.id)
          .where('siteId', isEqualTo: siteId)
          .get();

      final events = querySnapshot.docs
          .map((doc) => MonitoringEventRecord.fromJson(
                FirestoreDocumentHelpers.injectDocumentId(doc),
              ))
          .toList();
      // Sort in-memory instead of using orderBy
      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return events;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to get monitoring events for site',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get all monitoring events for a specific organism.
  @override
  Future<List<MonitoringEventRecord>> getMonitoringEventsForOrganism(
    String organismId,
  ) async {
    _ensureFeatureEnabled();
    try {
      // Use organizationId filter to satisfy security rules
      // Avoid orderBy to prevent composite index requirements
      final snapshots = await Future.wait([
        organizationQuery(collectionRef)
            .where('eventTypeId', isEqualTo: EventType.observation.id)
            .where('organismIds', arrayContains: organismId)
            .get(),
        organizationQuery(collectionRef)
            .where('eventTypeId', isEqualTo: EventType.observation.id)
            .where('coralIds', arrayContains: organismId)
            .get(),
      ]);

      final merged = <String, MonitoringEventRecord>{};
      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          merged[doc.id] = MonitoringEventRecord.fromJson(
            FirestoreDocumentHelpers.injectDocumentId(doc),
          );
        }
      }
      // Sort in-memory
      final events = merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return events;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to get monitoring events for organism',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get all monitoring events for a date range
  @override
  Future<List<MonitoringEventRecord>> getMonitoringEventsForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    _ensureFeatureEnabled();
    try {
      // Use organizationId filter to satisfy security rules
      // Note: Range queries with orderBy require composite indexes
      final querySnapshot = await organizationQuery(collectionRef)
          .where('eventTypeId', isEqualTo: EventType.observation.id)
          .where(
            'monitoringDate',
            isGreaterThanOrEqualTo: startDate.toIso8601String(),
          )
          .where(
            'monitoringDate',
            isLessThanOrEqualTo: endDate.toIso8601String(),
          )
          .get();

      final events = querySnapshot.docs
          .map((doc) => MonitoringEventRecord.fromJson(
                FirestoreDocumentHelpers.injectDocumentId(doc),
              ))
          .toList();
      // Sort in-memory instead of using orderBy
      events.sort((a, b) {
        final aDate = a.monitoringDate ?? DateTime.parse(a.createdAt);
        final bDate = b.monitoringDate ?? DateTime.parse(b.createdAt);
        return bDate.compareTo(aDate);
      });
      return events;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to get monitoring events for date range',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Update an existing monitoring event
  @override
  Future<MonitoringEventRecord> updateMonitoringEvent({
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
      final now = DateTimeConverter.nowAsIso8601String();

      // Get the existing event
      final docSnapshot = await collectionRef.doc(eventId).get();
      if (!docSnapshot.exists) {
        throw Exception('Monitoring event not found: $eventId');
      }

      final existingEvent = MonitoringEventRecord.fromJson(
        FirestoreDocumentHelpers.injectDocumentId(docSnapshot),
      );

      // Create updated event
      var updatedEvent = existingEvent.copyWith(
        newHealthStatus: newHealthStatus ?? existingEvent.newHealthStatus,
        comment: comment ?? existingEvent.comment,
        imageUrl: imageUrl ?? existingEvent.imageUrl,
        percentCover: percentCover ?? existingEvent.percentCover,
        percentBleaching: percentBleaching ?? existingEvent.percentBleaching,
        percentDisease: percentDisease ?? existingEvent.percentDisease,
        measurements: measurements ?? existingEvent.measurements,
        updatedAt: now,
        updatedById: user.id,
      );

      updatedEvent = withOrganismMetadata(updatedEvent);

      // Update in Firestore
      await collectionRef.doc(eventId).update(updatedEvent.toJson());
      LoggingService.instance.info('Updated monitoring event: $eventId');

      return updatedEvent;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to update monitoring event',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  void _ensureFeatureEnabled() {
    if (_featureEnabled) return;
    throw FeatureDisabledError(
      featureKey: featureKey,
      message: 'Monitoring workflows coming soon.',
      recoverySuggestion:
          'Upgrade to capture monitoring observations and imagery.',
    );
  }

  void _ensureImageryEnabled({
    String? imageUrl,
    required List<ImageAttachment> attachments,
  }) {
    final hasImagery =
        (imageUrl != null && imageUrl.isNotEmpty) || attachments.isNotEmpty;
    if (_imageryEnabled || !hasImagery) return;
    throw FeatureDisabledError(
      featureKey: imageryFeatureKey,
      message: 'Image attachments coming soon.',
      recoverySuggestion: 'Upgrade to attach imagery to monitoring events.',
    );
  }

  /// Fetch all monitoring events for the organization
  @override
  Future<List<MonitoringEventRecord>> fetchMonitoringEvents({
    DateTime? start,
    DateTime? end,
    String? siteId,
    bool attachOutplantGeometry = false,
  }) async {
    _ensureFeatureEnabled();
    try {
      // CRITICAL: Must include organizationId filter to satisfy security rules
      // Avoid orderBy to prevent composite index requirement issues
      Query<Map<String, dynamic>> query = organizationQuery(collectionRef)
          .where('eventTypeId', isEqualTo: EventType.observation.id);

      if (siteId != null) {
        query = query.where('siteId', isEqualTo: siteId);
      }

      if (start != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: start.toIso8601String(),
        );
      }

      if (end != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: end.toIso8601String(),
        );
      }

      final querySnapshot = await query.get();

      final events = querySnapshot.docs
          .map((doc) => MonitoringEventRecord.fromJson(
                FirestoreDocumentHelpers.injectDocumentId(doc),
              ))
          .toList();
      // Sort in-memory instead of using orderBy
      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return events;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to fetch monitoring events',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Stream all monitoring events for the organization.
  ///
  /// Implements [IMonitoringEventRepository.streamMonitoringEvents].
  @override
  Stream<List<MonitoringEventRecord>> streamMonitoringEvents({String? siteId}) {
    if (!_featureEnabled) {
      return Stream.value(const <MonitoringEventRecord>[]);
    }
    // CRITICAL: Must include organizationId filter to satisfy security rules
    // Must also filter by eventTypeId to return only monitoring events
    Query<Map<String, dynamic>> query = organizationQuery(collectionRef)
        .where('eventTypeId', isEqualTo: EventType.observation.id);
    if (siteId != null) {
      query = query.where('siteId', isEqualTo: siteId);
    }
    return query.snapshots().map((snapshot) {
      final events = snapshot.docs.map((doc) {
        return MonitoringEventRecord.fromJson(
          FirestoreDocumentHelpers.injectDocumentId(doc),
        );
      }).toList();
      // Sort in-memory instead of using orderBy
      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return events;
    });
  }
}
