// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/monitoring_schedule.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/repositories/utils/firestore_document_helpers.dart';
import 'package:seafoundry_app/services/firebase_service.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Service for managing monitoring schedules for restoration sites
///
/// This service provides CRUD operations and query capabilities for monitoring
/// schedules, enabling organizations to track permit compliance and ensure
/// sites are monitored at required intervals.
///
/// Key Features:
/// - Real-time streams of schedules for an organization
/// - Query overdue sites requiring immediate attention
/// - Query sites due soon (within N days) for planning
/// - Update schedules when monitoring is completed
/// - Full CRUD operations for schedule management
///
/// Design Decisions:
/// - Uses Firestore streams for real-time updates in the UI
/// - Leverages FirestoreCollectionResolver for demo-mode support
/// - Filters are performed at the query level for efficiency
/// - All operations include comprehensive logging for audit trails
class MonitoringScheduleService {
  final FirebaseFirestore _firestore;
  final LoggingService _logger;
  final FirestoreCollectionResolver _resolver;

  MonitoringScheduleService({
    FirebaseService? firebaseService,
    LoggingService? logger,
  })  : _firestore = (firebaseService ?? FirebaseService.instance).firestore,
        _logger = logger ?? LoggingService.instance,
        _resolver = FirestoreCollectionResolver.instance;

  String get _collectionPath => ModelType.monitoringSchedule.collectionPath;

  /// Get real-time stream of all schedules for an organization
  ///
  /// Returns a stream that emits the complete list of schedules whenever
  /// any schedule in the organization changes.
  Stream<List<MonitoringSchedule>> watchSchedulesForOrg(String orgId) {
    _logger.debug('Watching monitoring schedules for org: $orgId');

    return _resolver
        .collection(_firestore, _collectionPath)
        .where('organizationId', isEqualTo: orgId)
        .orderBy('nextDueDate', descending: false)
        .snapshots()
        .handleError((e, stackTrace) {
      _logger.error(
        'Failed to watch monitoring schedules for org: $orgId',
        e,
        stackTrace,
      );
    })
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        try {
          return MonitoringSchedule.fromJson(
            FirestoreDocumentHelpers.injectDocumentId(doc),
          );
        } catch (e) {
          _logger.warning(
            'Failed to parse monitoring schedule ${doc.id}: $e',
            e,
          );
          return null;
        }
      }).whereType<MonitoringSchedule>().toList();
    });
  }

  /// Get all overdue monitoring sites for an organization
  ///
  /// Returns sites where nextDueDate is in the past. These require
  /// immediate attention to maintain permit compliance.
  Future<List<MonitoringSchedule>> getOverdueSites(String orgId) async {
    try {
      _logger.debug('Getting overdue monitoring sites for org: $orgId');

      final now = DateTime.now();
      final snapshot = await _resolver
          .collection(_firestore, _collectionPath)
          .where('organizationId', isEqualTo: orgId)
          .where('nextDueDate', isLessThan: now.toIso8601String())
          .orderBy('nextDueDate', descending: false)
          .get();

      final schedules = snapshot.docs.map((doc) {
        return MonitoringSchedule.fromJson(
          FirestoreDocumentHelpers.injectDocumentId(doc),
        );
      }).toList();

      _logger.info('Found ${schedules.length} overdue sites for org: $orgId');
      return schedules;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get overdue monitoring sites for org: $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get sites due for monitoring within the next N days
  ///
  /// Useful for planning upcoming monitoring activities. Default is 7 days.
  /// Does not include overdue sites.
  Future<List<MonitoringSchedule>> getSitesDueSoon(
    String orgId, {
    int days = 7,
  }) async {
    try {
      _logger.debug(
        'Getting monitoring sites due within $days days for org: $orgId',
      );

      final now = DateTime.now();
      final futureDate = now.add(Duration(days: days));

      final snapshot = await _resolver
          .collection(_firestore, _collectionPath)
          .where('organizationId', isEqualTo: orgId)
          .where('nextDueDate', isGreaterThanOrEqualTo: now.toIso8601String())
          .where('nextDueDate', isLessThanOrEqualTo: futureDate.toIso8601String())
          .orderBy('nextDueDate', descending: false)
          .get();

      final schedules = snapshot.docs.map((doc) {
        return MonitoringSchedule.fromJson(
          FirestoreDocumentHelpers.injectDocumentId(doc),
        );
      }).toList();

      _logger.info(
        'Found ${schedules.length} sites due within $days days for org: $orgId',
      );
      return schedules;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get monitoring sites due soon for org: $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Record that monitoring was completed for a schedule
  ///
  /// Updates the schedule with the completion date and calculates the
  /// next due date based on the monitoring interval.
  ///
  /// This should be called after a monitoring event is logged to keep
  /// schedules in sync with actual monitoring activities.
  Future<void> recordMonitoringCompleted(
    String scheduleId,
    DateTime completedDate, {
    required String updatedById,
  }) async {
    try {
      _logger.info('Recording monitoring completion for schedule: $scheduleId');

      // Get the existing schedule
      final docRef = _resolver
          .collection(_firestore, _collectionPath)
          .doc(scheduleId);
      final doc = await docRef.get();

      final data = doc.data();
      if (!doc.exists || data == null) {
        throw Exception('Monitoring schedule not found or data is null: $scheduleId');
      }

      final schedule = MonitoringSchedule.fromJson(
        FirestoreDocumentHelpers.injectId(data, doc.id),
      );

      // Update with completed monitoring
      final updatedSchedule = schedule.withMonitoringCompleted(
        completedDate: completedDate,
        updatedById: updatedById,
      );

      await docRef.update(updatedSchedule.toJson());

      _logger.info(
        'Successfully recorded monitoring completion for schedule: $scheduleId',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to record monitoring completion for schedule: $scheduleId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Create a new monitoring schedule
  Future<MonitoringSchedule> createSchedule(
    MonitoringSchedule schedule,
  ) async {
    try {
      _logger.info('Creating monitoring schedule: ${schedule.id}');

      if (!schedule.validate()) {
        throw Exception('Invalid monitoring schedule');
      }

      final docRef = _resolver
          .collection(_firestore, _collectionPath)
          .doc(schedule.id);

      await docRef.set(schedule.toJson());

      _logger.info('Successfully created monitoring schedule: ${schedule.id}');
      return schedule;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to create monitoring schedule: ${schedule.id}',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Update an existing monitoring schedule
  Future<MonitoringSchedule> updateSchedule(
    MonitoringSchedule schedule,
  ) async {
    try {
      _logger.info('Updating monitoring schedule: ${schedule.id}');

      if (!schedule.validate()) {
        throw Exception('Invalid monitoring schedule');
      }

      final docRef = _resolver
          .collection(_firestore, _collectionPath)
          .doc(schedule.id);

      await docRef.update(schedule.toJson());

      _logger.info('Successfully updated monitoring schedule: ${schedule.id}');
      return schedule;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update monitoring schedule: ${schedule.id}',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a monitoring schedule
  Future<void> deleteSchedule(String scheduleId) async {
    try {
      _logger.info('Deleting monitoring schedule: $scheduleId');

      final docRef = _resolver
          .collection(_firestore, _collectionPath)
          .doc(scheduleId);

      await docRef.delete();

      _logger.info('Successfully deleted monitoring schedule: $scheduleId');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete monitoring schedule: $scheduleId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get a single monitoring schedule by ID
  Future<MonitoringSchedule?> getScheduleById(String scheduleId) async {
    try {
      _logger.debug('Getting monitoring schedule by ID: $scheduleId');

      final docRef = _resolver
          .collection(_firestore, _collectionPath)
          .doc(scheduleId);
      final doc = await docRef.get();

      final data = doc.data();
      if (!doc.exists || data == null) {
        _logger.debug('Monitoring schedule not found: $scheduleId');
        return null;
      }

      return MonitoringSchedule.fromJson(
        FirestoreDocumentHelpers.injectId(data, doc.id),
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get monitoring schedule: $scheduleId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get all schedules for a specific site
  Future<List<MonitoringSchedule>> getSchedulesForSite(String siteId) async {
    try {
      _logger.debug('Getting monitoring schedules for site: $siteId');

      final snapshot = await _resolver
          .collection(_firestore, _collectionPath)
          .where('siteId', isEqualTo: siteId)
          .orderBy('nextDueDate', descending: false)
          .get();

      final schedules = snapshot.docs.map((doc) {
        return MonitoringSchedule.fromJson(
          FirestoreDocumentHelpers.injectDocumentId(doc),
        );
      }).toList();

      _logger.info('Found ${schedules.length} schedules for site: $siteId');
      return schedules;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get monitoring schedules for site: $siteId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Stream monitoring schedules for a specific site
  Stream<List<MonitoringSchedule>> watchSchedulesForSite(String siteId) {
    _logger.debug('Watching monitoring schedules for site: $siteId');

    return _resolver
        .collection(_firestore, _collectionPath)
        .where('siteId', isEqualTo: siteId)
        .orderBy('nextDueDate', descending: false)
        .snapshots()
        .handleError((e, stackTrace) {
      _logger.error(
        'Failed to watch monitoring schedules for site: $siteId',
        e,
        stackTrace,
      );
    })
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        try {
          return MonitoringSchedule.fromJson(
            FirestoreDocumentHelpers.injectDocumentId(doc),
          );
        } catch (e) {
          _logger.warning(
            'Failed to parse monitoring schedule ${doc.id}: $e',
            e,
          );
          return null;
        }
      }).whereType<MonitoringSchedule>().toList();
    });
  }

  /// Get count of overdue sites for an organization
  ///
  /// Useful for dashboard badges and quick status checks without loading
  /// all schedule data.
  Future<int> getOverdueCount(String orgId) async {
    try {
      final overdueSchedules = await getOverdueSites(orgId);
      return overdueSchedules.length;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get overdue count for org: $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}
