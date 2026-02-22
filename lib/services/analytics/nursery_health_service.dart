// @tier: community
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/types/health_status.dart';

/// Performance-optimized service for aggregating nursery health metrics
/// at site and structure levels.
class NurseryHealthService {
  /// Aggregates health data for a collection of organisms.
  /// Returns the most severe health status if it exceeds a threshold.
  /// If [organisms] is empty, returns [HealthStatus.unknown]. This is the expected
  /// behavior for sites with no recorded organisms.
  static HealthStatus computeAggregateStatus(List<OrganismRecord> organisms) {
    if (organisms.isEmpty) return HealthStatus.unknown;
    
    int healthy = 0;
    int caution = 0;
    int critical = 0;
    
    for (final o in organisms) {
      final status = o.healthStatus;
      if (status.isHealthy) {
        healthy++;
      } else if (status == HealthStatus.stressed || status == HealthStatus.bleached || status == HealthStatus.damaged) {
        caution++;
      } else if (status == HealthStatus.diseased) {
        critical++;
      }
    }
    
    final total = healthy + caution + critical;
    if (total == 0) return HealthStatus.unknown;

    // Thresholds:
    // - Any 'critical' (diseased) record markers the aggregate as diseased (safety first)
    // - More than 10% 'caution' (stressed/bleached/damaged) marks the aggregate as stressed
    if (critical > 0) return HealthStatus.diseased;
    if (caution > (total * 0.1)) return HealthStatus.stressed;
    
    return HealthStatus.healthy;
  }

  /// Calculates the percentage of healthy organisms.
  static double calculateHealthScore(List<OrganismRecord> organisms) {
    if (organisms.isEmpty) return 100.0;
    
    int healthy = 0;
    for (final o in organisms) {
      if (o.healthStatus.isHealthy) {
        healthy++;
      }
    }
    
    return (healthy / organisms.length) * 100.0;
  }
}

/// Data snapshot for map visualization
class NurseryHealthPoint {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final HealthStatus healthStatus;
  final double score;
  final int organismCount;

  NurseryHealthPoint({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.healthStatus,
    required this.score,
    required this.organismCount,
  });
}
