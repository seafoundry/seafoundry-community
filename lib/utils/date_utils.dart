// @tier: community
import 'package:intl/intl.dart';

/// Human-readable date/time formatting using `intl` package.
///
/// **When to use:**
/// - Displaying dates to users in localized format (e.g., "Jan 15, 2026")
/// - Showing relative time ("2 hours ago")
/// - Parsing timestamps from various sources (Firestore, JSON)
///
/// **Related utilities:**
/// - [DateFormatter]: UI-focused (due dates, durations, chat times)
/// - [DateTimeConverter]: ISO 8601 serialization for Firestore/data layer
class DateTimeUtils {
  /// Format a DateTime as a readable date string (e.g., "Jan 15, 2026")
  static String formatDate(DateTime date) {
    return DateFormat.yMMMd().format(date);
  }

  /// Format a DateTime as a short date string (e.g., "1/15/26")
  static String formatShortDate(DateTime date) {
    return DateFormat.yMd().format(date);
  }

  /// Format a DateTime as a time string (e.g., "2:30 PM")
  static String formatTime(DateTime date) {
    return DateFormat.jm().format(date);
  }

  /// Format a DateTime as date and time (e.g., "Jan 15, 2026 2:30 PM")
  static String formatDateTime(DateTime date) {
    return DateFormat.yMMMd().add_jm().format(date);
  }

  /// Safely parse a timestamp from various formats (DateTime, int, String).
  /// Returns DateTime.now() as fallback if parsing fails.
  static DateTime parseTimestamp(Object timestamp) {
    if (timestamp is DateTime) {
      return timestamp;
    }
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        // Invalid timestamp format, return current time as fallback
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  /// Safely parse a timestamp string, returning null if invalid.
  /// Prefer this when null is a valid/expected outcome.
  static DateTime? tryParseTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return null;
    try {
      return DateTime.parse(timestamp);
    } catch (e) {
      return null;
    }
  }

  static String timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years${years == 1 ? ' year' : ' years'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months${months == 1 ? ' month' : ' months'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}${difference.inDays == 1 ? ' day' : ' days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}${difference.inHours == 1 ? ' hour' : ' hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}${difference.inMinutes == 1 ? ' minute' : ' minutes'} ago';
    } else {
      return 'just now';
    }
  }
}
