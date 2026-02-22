// @tier: community
import 'package:seafoundry_app/models/events/inventory_event.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/records/inventory_record.dart';
import 'package:seafoundry_app/models/types/health_status.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Service for comparing inventory and genetic records across different time periods
/// using snapshot records to determine how inventory has changed over time
class SnapshotComparisonService {
  /// Compare inventory records at two different points in time
  Future<InventoryComparison> compareInventorySnapshots({
    required String recordId,
    required ModelType recordModelType,
    required DateTime pointInTime1,
    required DateTime pointInTime2,
    List<InventoryEvent>? events,
  }) async {
    try {
      // Find snapshots closest to the specified points in time
      final snapshot1 = await _findSnapshotAtTime(
        recordId,
        pointInTime1,
        events,
      );
      final snapshot2 = await _findSnapshotAtTime(
        recordId,
        pointInTime2,
        events,
      );

      if (snapshot1 == null || snapshot2 == null) {
        throw Exception(
          'Could not find snapshots for the specified time points',
        );
      }

      // Calculate differences
      final differences = _calculateInventoryDifferences(snapshot1, snapshot2);
      final changes = _categorizeChanges(differences);

      return InventoryComparison(
        recordId: recordId,
        recordModelType: recordModelType,
        pointInTime1: pointInTime1,
        pointInTime2: pointInTime2,
        snapshot1: snapshot1,
        snapshot2: snapshot2,
        differences: differences,
        changes: changes,
        hasChanges: differences.isNotEmpty,
      );
    } catch (e) {
      LoggingService.instance.error(
        'Failed to compare inventory snapshots for $recordId',
        e,
      );
      rethrow;
    }
  }

  /// Compare genetic records at two different points in time
  Future<GeneticComparison> compareGeneticSnapshots({
    required String genetId,
    required DateTime pointInTime1,
    required DateTime pointInTime2,
    List<InventoryEvent>? events,
  }) async {
    try {
      // Find genetic snapshots closest to the specified points in time
      final snapshot1 = await _findGeneticSnapshotAtTime(
        genetId,
        pointInTime1,
        events,
      );
      final snapshot2 = await _findGeneticSnapshotAtTime(
        genetId,
        pointInTime2,
        events,
      );

      if (snapshot1 == null || snapshot2 == null) {
        throw Exception(
          'Could not find genetic snapshots for the specified time points',
        );
      }

      // Calculate genetic differences
      final differences = _calculateGeneticDifferences(snapshot1, snapshot2);
      final changes = _categorizeGeneticChanges(differences);

      return GeneticComparison(
        genetId: genetId,
        pointInTime1: pointInTime1,
        pointInTime2: pointInTime2,
        snapshot1: snapshot1,
        snapshot2: snapshot2,
        differences: differences,
        changes: changes,
        hasChanges: differences.isNotEmpty,
      );
    } catch (e) {
      LoggingService.instance.error(
        'Failed to compare genetic snapshots for $genetId',
        e,
      );
      rethrow;
    }
  }

  /// Generate a comprehensive comparison report for multiple records
  Future<ComparisonReport> generateComparisonReport({
    required List<String> recordIds,
    required ModelType recordModelType,
    required DateTime pointInTime1,
    required DateTime pointInTime2,
    List<InventoryEvent>? events,
  }) async {
    try {
      final comparisons = <InventoryComparison>[];
      final summary = <String, dynamic>{};

      for (final recordId in recordIds) {
        final comparison = await compareInventorySnapshots(
          recordId: recordId,
          recordModelType: recordModelType,
          pointInTime1: pointInTime1,
          pointInTime2: pointInTime2,
          events: events,
        );
        comparisons.add(comparison);
      }

      // Generate summary statistics
      summary['totalRecords'] = recordIds.length;
      summary['recordsWithChanges'] = comparisons
          .where((c) => c.hasChanges)
          .length;
      summary['totalChanges'] = comparisons.fold(
        0,
        (sum, c) => sum + c.differences.length,
      );
      summary['changeTypes'] = _summarizeChangeTypes(comparisons);

      return ComparisonReport(
        recordIds: recordIds,
        recordModelType: recordModelType,
        pointInTime1: pointInTime1,
        pointInTime2: pointInTime2,
        comparisons: comparisons,
        summary: summary,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      LoggingService.instance.error('Failed to generate comparison report', e);
      rethrow;
    }
  }

  /// Find the snapshot closest to a specific point in time
  Future<InventoryRecord?> _findSnapshotAtTime(
    String recordId,
    DateTime pointInTime,
    List<InventoryEvent>? events,
  ) async {
    if (events == null) return null;

    // Filter events for this record
    final recordEvents = events
        .where((event) => event.recordId == recordId)
        .toList();

    if (recordEvents.isEmpty) return null;

    // Sort events by creation time
    recordEvents.sort(
      (a, b) =>
          DateTime.parse(a.createdAt).compareTo(DateTime.parse(b.createdAt)),
    );

    // Find the event closest to the point in time
    InventoryEvent? closestEvent;
    DateTime? closestTime;

    for (final event in recordEvents) {
      final eventTime = DateTime.parse(event.createdAt);
      if (eventTime.isBefore(pointInTime) ||
          eventTime.isAtSameMomentAs(pointInTime)) {
        if (closestTime == null || eventTime.isAfter(closestTime)) {
          closestEvent = event;
          closestTime = eventTime;
        }
      }
    }

    return closestEvent?.snapshot;
  }

  /// Find the genetic snapshot closest to a specific point in time
  Future<Genet?> _findGeneticSnapshotAtTime(
    String genetId,
    DateTime pointInTime,
    List<InventoryEvent>? events,
  ) async {
    if (events == null) return null;

    // Filter events for this genet
    final genetEvents = events
        .where(
          (event) =>
              event.recordId == genetId &&
              event.recordModelType.name == 'genet',
        )
        .toList();

    if (genetEvents.isEmpty) return null;

    // Sort events by creation time
    genetEvents.sort(
      (a, b) =>
          DateTime.parse(a.createdAt).compareTo(DateTime.parse(b.createdAt)),
    );

    // Find the event closest to the point in time
    InventoryEvent? closestEvent;
    DateTime? closestTime;

    for (final event in genetEvents) {
      final eventTime = DateTime.parse(event.createdAt);
      if (eventTime.isBefore(pointInTime) ||
          eventTime.isAtSameMomentAs(pointInTime)) {
        if (closestTime == null || eventTime.isAfter(closestTime)) {
          closestEvent = event;
          closestTime = eventTime;
        }
      }
    }

    return closestEvent?.snapshot as Genet?;
  }

  /// Calculate differences between two inventory records
  Map<String, dynamic> _calculateInventoryDifferences(
    InventoryRecord snapshot1,
    InventoryRecord snapshot2,
  ) {
    final differences = <String, dynamic>{};

    // Compare common properties
    if (snapshot1.id != snapshot2.id) {
      differences['id'] = {'from': snapshot1.id, 'to': snapshot2.id};
    }
    if (snapshot1.createdAt != snapshot2.createdAt) {
      differences['createdAt'] = {
        'from': snapshot1.createdAt,
        'to': snapshot2.createdAt,
      };
    }
    if (snapshot1.updatedAt != snapshot2.updatedAt) {
      differences['updatedAt'] = {
        'from': snapshot1.updatedAt,
        'to': snapshot2.updatedAt,
      };
    }

    // Compare model-specific properties
    if (snapshot1 is OrganismRecord && snapshot2 is OrganismRecord) {
      final name1 = snapshot1.name;
      final name2 = snapshot2.name;
      if (name1 != name2) {
        differences['name'] = {'from': name1, 'to': name2};
      }

      final quantity1 = snapshot1.measurement.value.round();
      final quantity2 = snapshot2.measurement.value.round();
      if (quantity1 != quantity2) {
        differences['quantity'] = {
          'from': quantity1,
          'to': quantity2,
        };
      }

      final healthStatus1 = HealthStatus.fromId(
        snapshot1.metadata?['healthStatus'] as String? ?? 'healthy'
      );
      final healthStatus2 = HealthStatus.fromId(
        snapshot2.metadata?['healthStatus'] as String? ?? 'healthy'
      );
      if (healthStatus1 != healthStatus2) {
        differences['healthStatus'] = {
          'from': healthStatus1,
          'to': healthStatus2,
        };
      }

      if (snapshot1.speciesId != snapshot2.speciesId) {
        differences['speciesId'] = {
          'from': snapshot1.speciesId,
          'to': snapshot2.speciesId,
        };
      }

      final genetId1 = GenetIdResolver.resolve(snapshot1) ?? '';
      final genetId2 = GenetIdResolver.resolve(snapshot2) ?? '';
      if (genetId1 != genetId2) {
        differences['genetId'] = {
          'from': genetId1,
          'to': genetId2,
        };
      }

      if (snapshot1.localId != snapshot2.localId) {
        differences['urlPath'] = {
          'from': snapshot1.localId,
          'to': snapshot2.localId,
        };
      }
    }

    return differences;
  }

  /// Calculate differences between two genetic records
  Map<String, dynamic> _calculateGeneticDifferences(
    Genet snapshot1,
    Genet snapshot2,
  ) {
    final differences = <String, dynamic>{};

    // Compare common properties
    if (snapshot1.id != snapshot2.id) {
      differences['id'] = {'from': snapshot1.id, 'to': snapshot2.id};
    }
    if (snapshot1.name != snapshot2.name) {
      differences['name'] = {'from': snapshot1.name, 'to': snapshot2.name};
    }
    if (snapshot1.speciesId != snapshot2.speciesId) {
      differences['speciesId'] = {
        'from': snapshot1.speciesId,
        'to': snapshot2.speciesId,
      };
    }
    if (snapshot1.provenanceTypeId != snapshot2.provenanceTypeId) {
      differences['provenanceTypeId'] = {
        'from': snapshot1.provenanceTypeId,
        'to': snapshot2.provenanceTypeId,
      };
    }
    if (snapshot1.provenanceId != snapshot2.provenanceId) {
      differences['provenanceId'] = {'from': snapshot1.provenanceId, 'to': snapshot2.provenanceId};
    }
    if (snapshot1.clonalId != snapshot2.clonalId) {
      differences['clonalId'] = {
        'from': snapshot1.clonalId,
        'to': snapshot2.clonalId,
      };
    }
    if (snapshot1.accessionNumber != snapshot2.accessionNumber) {
      differences['accessionNumber'] = {
        'from': snapshot1.accessionNumber,
        'to': snapshot2.accessionNumber,
      };
    }
    if (snapshot1.notes != snapshot2.notes) {
      differences['notes'] = {'from': snapshot1.notes, 'to': snapshot2.notes};
    }
    if (snapshot1.provenance != snapshot2.provenance) {
      differences['provenance'] = {
        'from': snapshot1.provenance,
        'to': snapshot2.provenance,
      };
    }

    return differences;
  }

  /// Categorize changes by type and significance
  Map<String, dynamic> _categorizeChanges(Map<String, dynamic> differences) {
    final changes = <String, dynamic>{
      'critical': <String, dynamic>{},
      'significant': <String, dynamic>{},
      'minor': <String, dynamic>{},
    };

    for (final entry in differences.entries) {
      final field = entry.key;
      final change = entry.value;

      if (_isCriticalChange(field, change)) {
        changes['critical'][field] = change;
      } else if (_isSignificantChange(field, change)) {
        changes['significant'][field] = change;
      } else {
        changes['minor'][field] = change;
      }
    }

    return changes;
  }

  /// Categorize genetic changes by type and significance
  Map<String, dynamic> _categorizeGeneticChanges(
    Map<String, dynamic> differences,
  ) {
    final changes = <String, dynamic>{
      'critical': <String, dynamic>{},
      'significant': <String, dynamic>{},
      'minor': <String, dynamic>{},
    };

    for (final entry in differences.entries) {
      final field = entry.key;
      final change = entry.value;

      if (_isCriticalGeneticChange(field, change)) {
        changes['critical'][field] = change;
      } else if (_isSignificantGeneticChange(field, change)) {
        changes['significant'][field] = change;
      } else {
        changes['minor'][field] = change;
      }
    }

    return changes;
  }

  /// Check if a change is critical
  bool _isCriticalChange(String field, dynamic change) {
    const criticalFields = ['id', 'speciesId', 'genetId'];
    return criticalFields.contains(field);
  }

  /// Check if a change is significant
  bool _isSignificantChange(String field, dynamic change) {
    const significantFields = ['healthStatus', 'quantity', 'urlPath'];
    return significantFields.contains(field);
  }

  /// Check if a genetic change is critical
  bool _isCriticalGeneticChange(String field, dynamic change) {
    const criticalFields = ['id', 'speciesId', 'provenanceTypeId', 'provenanceId'];
    return criticalFields.contains(field);
  }

  /// Check if a genetic change is significant
  bool _isSignificantGeneticChange(String field, dynamic change) {
    const significantFields = ['name', 'clonalId', 'accessionNumber'];
    return significantFields.contains(field);
  }

  /// Summarize change types across multiple comparisons
  Map<String, int> _summarizeChangeTypes(
    List<InventoryComparison> comparisons,
  ) {
    final summary = <String, int>{};

    for (final comparison in comparisons) {
      for (final field in comparison.differences.keys) {
        summary[field] = (summary[field] ?? 0) + 1;
      }
    }

    return summary;
  }
}

/// Represents a comparison between two inventory snapshots
class InventoryComparison {
  final String recordId;
  final ModelType recordModelType;
  final DateTime pointInTime1;
  final DateTime pointInTime2;
  final InventoryRecord snapshot1;
  final InventoryRecord snapshot2;
  final Map<String, dynamic> differences;
  final Map<String, dynamic> changes;
  final bool hasChanges;

  const InventoryComparison({
    required this.recordId,
    required this.recordModelType,
    required this.pointInTime1,
    required this.pointInTime2,
    required this.snapshot1,
    required this.snapshot2,
    required this.differences,
    required this.changes,
    required this.hasChanges,
  });

  /// Get critical changes
  Map<String, dynamic> get criticalChanges =>
      changes['critical'] as Map<String, dynamic>;

  /// Get significant changes
  Map<String, dynamic> get significantChanges =>
      changes['significant'] as Map<String, dynamic>;

  /// Get minor changes
  Map<String, dynamic> get minorChanges =>
      changes['minor'] as Map<String, dynamic>;

  /// Get a summary of changes
  String get changeSummary {
    if (!hasChanges) return 'No changes detected';

    final criticalCount = criticalChanges.length;
    final significantCount = significantChanges.length;
    final minorCount = minorChanges.length;

    final parts = <String>[];
    if (criticalCount > 0) parts.add('$criticalCount critical');
    if (significantCount > 0) parts.add('$significantCount significant');
    if (minorCount > 0) parts.add('$minorCount minor');

    return '${parts.join(', ')} changes detected';
  }
}

/// Represents a comparison between two genetic snapshots
class GeneticComparison {
  final String genetId;
  final DateTime pointInTime1;
  final DateTime pointInTime2;
  final Genet snapshot1;
  final Genet snapshot2;
  final Map<String, dynamic> differences;
  final Map<String, dynamic> changes;
  final bool hasChanges;

  const GeneticComparison({
    required this.genetId,
    required this.pointInTime1,
    required this.pointInTime2,
    required this.snapshot1,
    required this.snapshot2,
    required this.differences,
    required this.changes,
    required this.hasChanges,
  });

  /// Get critical changes
  Map<String, dynamic> get criticalChanges =>
      changes['critical'] as Map<String, dynamic>;

  /// Get significant changes
  Map<String, dynamic> get significantChanges =>
      changes['significant'] as Map<String, dynamic>;

  /// Get minor changes
  Map<String, dynamic> get minorChanges =>
      changes['minor'] as Map<String, dynamic>;

  /// Get a summary of changes
  String get changeSummary {
    if (!hasChanges) return 'No changes detected';

    final criticalCount = criticalChanges.length;
    final significantCount = significantChanges.length;
    final minorCount = minorChanges.length;

    final parts = <String>[];
    if (criticalCount > 0) parts.add('$criticalCount critical');
    if (significantCount > 0) parts.add('$significantCount significant');
    if (minorCount > 0) parts.add('$minorCount minor');

    return '${parts.join(', ')} changes detected';
  }
}

/// Represents a comprehensive comparison report
class ComparisonReport {
  final List<String> recordIds;
  final ModelType recordModelType;
  final DateTime pointInTime1;
  final DateTime pointInTime2;
  final List<InventoryComparison> comparisons;
  final Map<String, dynamic> summary;
  final DateTime generatedAt;

  const ComparisonReport({
    required this.recordIds,
    required this.recordModelType,
    required this.pointInTime1,
    required this.pointInTime2,
    required this.comparisons,
    required this.summary,
    required this.generatedAt,
  });

  /// Get total number of records
  int get totalRecords => summary['totalRecords'] as int;

  /// Get number of records with changes
  int get recordsWithChanges => summary['recordsWithChanges'] as int;

  /// Get total number of changes
  int get totalChanges => summary['totalChanges'] as int;

  /// Get change types summary
  Map<String, int> get changeTypes =>
      summary['changeTypes'] as Map<String, int>;

  /// Get percentage of records with changes
  double get changePercentage =>
      totalRecords > 0 ? (recordsWithChanges / totalRecords) * 100 : 0.0;
}
