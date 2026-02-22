// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/reporting/report_configuration.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Repository for managing saved report configurations.
///
/// Reports are stored as a subcollection under organizations:
/// `organizations/{orgId}/reports/{reportId}`
///
/// Each report has a 30-day TTL (ttlExpiry field) for automatic cleanup.
class ReportConfigurationRepository {
  final FirebaseFirestore _firestore;
  final LoggingService _logger;
  final FirestoreCollectionResolver _resolver =
      FirestoreCollectionResolver.instance;

  /// TTL duration for saved reports (30 days).
  static const Duration ttlDuration = Duration(days: 30);

  ReportConfigurationRepository({
    required FirebaseFirestore firestore,
    LoggingService? logger,
  })  : _firestore = firestore,
        _logger = logger ?? LoggingService.instance;

  /// Get the reports collection for an organization.
  CollectionReference<Map<String, dynamic>> _reportsCollection(String orgId) {
    return _resolver.subcollection(
      _firestore,
      'organizations',
      orgId,
      'reports',
    );
  }

  /// Watch all reports for an organization.
  ///
  /// Returns reports ordered by updatedAt descending (most recent first).
  /// Excludes expired reports (ttlExpiry < now).
  Stream<List<ReportConfiguration>> watchReportsForOrg(String orgId) {
    try {
      final now = DateTime.now();
      // Avoid orderBy to prevent composite index requirements - sort in-memory
      return _reportsCollection(orgId)
          .where('ttlExpiry', isGreaterThan: now.toIso8601String())
          .snapshots()
          .map((snapshot) {
        final reports = <ReportConfiguration>[];
        for (final doc in snapshot.docs) {
          final report = _parseReport(doc);
          if (report != null) {
            reports.add(report);
          }
        }
        // Sort in-memory by updatedAt descending (newest first)
        reports.sort((a, b) {
          final aUpdated = a.updatedAt ?? a.createdAt ?? DateTime(1970);
          final bUpdated = b.updatedAt ?? b.createdAt ?? DateTime(1970);
          return bUpdated.compareTo(aUpdated);
        });
        return reports;
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to watch reports for org $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get all reports for an organization (one-time fetch).
  ///
  /// Returns reports ordered by updatedAt descending (most recent first).
  /// Excludes expired reports.
  Future<List<ReportConfiguration>> getReportsForOrg(String orgId) async {
    try {
      final now = DateTime.now();
      final snapshot = await _reportsCollection(orgId)
          .where('ttlExpiry', isGreaterThan: now.toIso8601String())
          .orderBy('ttlExpiry', descending: false)
          .orderBy('updatedAt', descending: true)
          .get();

      final reports = <ReportConfiguration>[];
      for (final doc in snapshot.docs) {
        final report = _parseReport(doc);
        if (report != null) {
          reports.add(report);
        }
      }
      return reports;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get reports for org $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get a report by ID.
  Future<ReportConfiguration?> getReportById(
    String orgId,
    String reportId,
  ) async {
    try {
      final doc = await _reportsCollection(orgId).doc(reportId).get();
      if (!doc.exists) return null;

      final report = _parseReport(doc);

      // Check if report has expired
      if (report != null && report.metadata['ttlExpiry'] != null) {
        final ttlExpiry = DateTime.parse(report.metadata['ttlExpiry'] as String);
        if (ttlExpiry.isBefore(DateTime.now())) {
          return null; // Report has expired
        }
      }

      return report;
    } catch (e, stackTrace) {
      _logger.error('Failed to get report $reportId', e, stackTrace);
      rethrow;
    }
  }

  /// Create a new report.
  ///
  /// Sets ttlExpiry to 30 days from now.
  Future<String> createReport(
    String orgId,
    ReportConfiguration report,
  ) async {
    try {
      final now = DateTime.now();
      final ttlExpiry = now.add(ttlDuration);

      final docRef = report.id.isEmpty
          ? _reportsCollection(orgId).doc()
          : _reportsCollection(orgId).doc(report.id);

      final reportToSave = report.copyWith(
        id: docRef.id,
        organizationId: orgId,
        createdAt: report.createdAt ?? now,
        updatedAt: now,
        metadata: {
          ...report.metadata,
          'ttlExpiry': ttlExpiry.toIso8601String(),
        },
      );

      final data = reportToSave.toJson();
      data['ttlExpiry'] = ttlExpiry.toIso8601String();

      await docRef.set(data);
      return docRef.id;
    } catch (e, stackTrace) {
      _logger.error('Failed to create report', e, stackTrace);
      rethrow;
    }
  }

  /// Update an existing report.
  ///
  /// Refreshes ttlExpiry to 30 days from now.
  Future<void> updateReport(
    String orgId,
    ReportConfiguration report,
  ) async {
    try {
      if (report.id.isEmpty) {
        throw ArgumentError('Report ID is required for update');
      }

      final now = DateTime.now();
      final ttlExpiry = now.add(ttlDuration);

      final reportToSave = report.copyWith(
        updatedAt: now,
        metadata: {
          ...report.metadata,
          'ttlExpiry': ttlExpiry.toIso8601String(),
        },
      );

      final data = reportToSave.toJson();
      data['ttlExpiry'] = ttlExpiry.toIso8601String();

      await _reportsCollection(orgId).doc(report.id).update(data);
    } catch (e, stackTrace) {
      _logger.error('Failed to update report ${report.id}', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a report.
  Future<void> deleteReport(String orgId, String reportId) async {
    try {
      await _reportsCollection(orgId).doc(reportId).delete();
    } catch (e, stackTrace) {
      _logger.error('Failed to delete report $reportId', e, stackTrace);
      rethrow;
    }
  }

  /// Extend the TTL of a report by another 30 days.
  ///
  /// Useful when a user accesses a report to keep it alive.
  Future<void> extendTtl(String orgId, String reportId) async {
    try {
      final now = DateTime.now();
      final ttlExpiry = now.add(ttlDuration);

      await _reportsCollection(orgId).doc(reportId).update({
        'ttlExpiry': ttlExpiry.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to extend TTL for report $reportId', e, stackTrace);
      rethrow;
    }
  }

  /// Parse a Firestore document into a ReportConfiguration.
  ReportConfiguration? _parseReport(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      _logger.warning(
        'Report ${doc.id} exists but has null data; skipping parse',
        {'docId': doc.id},
      );
      return null;
    }
    try {
      data['id'] = doc.id;
      return ReportConfiguration.fromJson(data);
    } catch (e, stackTrace) {
      _logger.error('Failed to parse report ${doc.id}', e, stackTrace);
      return null;
    }
  }
}
