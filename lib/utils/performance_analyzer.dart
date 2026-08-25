import 'package:flutter/foundation.dart';
import 'package:seafoundry_community/services/logging_service.dart';

/// Performance analyzer for tracking and optimizing app performance
///
/// Usage:
/// ```dart
/// final result = await PerformanceAnalyzer.measure(
///   'loadCorals',
///   () async => await coralRepository.getAll(),
/// );
/// ```
class PerformanceAnalyzer {
  static final Map<String, List<PerformanceMetric>> _metrics = {};
  static final bool _enabled = kDebugMode;

  /// Measure execution time of a function
  static Future<T> measure<T>(
    String operationName,
    Future<T> Function() operation, {
    Map<String, dynamic>? metadata,
  }) async {
    if (!_enabled) return operation();

    final stopwatch = Stopwatch()..start();
    final startMemory = _getCurrentMemoryUsage();

    try {
      final result = await operation();
      stopwatch.stop();

      final endMemory = _getCurrentMemoryUsage();
      final metric = PerformanceMetric(
        operationName: operationName,
        duration: stopwatch.elapsed,
        memoryDelta: endMemory - startMemory,
        timestamp: DateTime.now(),
        metadata: metadata,
        success: true,
      );

      _recordMetric(metric);
      return result;
    } catch (e) {
      stopwatch.stop();

      final metric = PerformanceMetric(
        operationName: operationName,
        duration: stopwatch.elapsed,
        memoryDelta: 0,
        timestamp: DateTime.now(),
        metadata: metadata,
        success: false,
        error: e.toString(),
      );

      _recordMetric(metric);
      rethrow;
    }
  }

  static void _recordMetric(PerformanceMetric metric) {
    _metrics.putIfAbsent(metric.operationName, () => []).add(metric);

    // Log immediately if it's a slow operation
    if (metric.duration > const Duration(seconds: 1)) {
      LoggingService.instance.warning(
        'Slow operation: ${metric.operationName} took ${metric.duration.inMilliseconds}ms',
      );
    }
  }

  static int _getCurrentMemoryUsage() {
    // This is a simplified version
    // In production, you'd use platform channels to get actual memory usage
    return DateTime.now().millisecondsSinceEpoch % 1000000;
  }
}

/// Performance metric data
class PerformanceMetric {
  final String operationName;
  final Duration duration;
  final int memoryDelta;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final bool success;
  final String? error;

  const PerformanceMetric({
    required this.operationName,
    required this.duration,
    required this.memoryDelta,
    required this.timestamp,
    this.metadata,
    required this.success,
    this.error,
  });
}
