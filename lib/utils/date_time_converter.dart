import 'package:seafoundry_app/services/logging_service.dart';

/// ISO 8601 date/time conversion for data layer serialization.
///
/// **When to use:**
/// - Converting DateTime to/from Firestore strings
/// - Parsing JSON date fields with telemetry
/// - System-level date handling (not user display)
///
/// **Related utilities:**
/// - [DateTimeUtils]: Localized display formats with `intl`
/// - [DateFormatter]: UI-focused (due dates, durations, chat times)
class DateTimeConverter {
  /// Converts a DateTime to an ISO 8601 string
  static String toIso8601String(DateTime dateTime) {
    return dateTime.toIso8601String();
  }

  /// Converts an ISO 8601 string to a DateTime
  static DateTime? fromIso8601String(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) {
      return null;
    }
    return DateTime.parse(dateTimeString);
  }

  /// Parses a date with fallback, logging telemetry when fallback is used.
  ///
  /// Use this for required date fields in fromJson to track records with
  /// missing data. The [fieldName] and [modelType] help identify affected
  /// records for data migration.
  ///
  /// Example:
  /// ```dart
  /// dueDate = DateTimeConverter.parseWithFallback(
  ///   json['dueDate'],
  ///   fallback: DateTime.now().add(Duration(days: 30)),
  ///   fieldName: 'dueDate',
  ///   modelType: 'Deliverable',
  ///   recordId: json['id'],
  /// );
  /// ```
  static DateTime parseWithFallback(
    String? dateTimeString, {
    required DateTime fallback,
    required String fieldName,
    required String modelType,
    String? recordId,
  }) {
    if (dateTimeString != null && dateTimeString.isNotEmpty) {
      try {
        return DateTime.parse(dateTimeString);
      } catch (_) {
        // Invalid date format - log and use fallback
        LoggingService.instance
            .warning('DateTime parse failed for $modelType.$fieldName', {
              'recordId': recordId,
              'modelType': modelType,
              'fieldName': fieldName,
              'invalidValue': dateTimeString,
              'fallbackUsed': fallback.toIso8601String(),
            });
        return fallback;
      }
    }

    // Missing date field - log telemetry for data migration
    LoggingService.instance
        .warning('DateTime fallback used for $modelType.$fieldName', {
          'recordId': recordId,
          'modelType': modelType,
          'fieldName': fieldName,
          'fallbackUsed': fallback.toIso8601String(),
        });
    return fallback;
  }

  /// Gets the current time as an ISO 8601 string
  static String nowAsIso8601String() {
    return DateTime.now().toIso8601String();
  }

  /// Formats a DateTime for display (YYYY-MM-DD)
  static String formatDate(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  /// Formats a DateTime for display (YYYY-MM-DD HH:MM)
  static String formatDateTime(DateTime dateTime) {
    return '${formatDate(dateTime)} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
