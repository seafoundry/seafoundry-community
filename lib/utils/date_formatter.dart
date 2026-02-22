// @tier: community
import 'package:flutter/material.dart';

/// UI-focused date/time formatting for widgets.
///
/// **When to use:**
/// - Due date indicators with colors (overdue, upcoming)
/// - Chat/message timestamps ("Yesterday", "Monday")
/// - Duration formatting ("2h 15m", "15:30")
/// - ISO date for YAML config files
///
/// **Related utilities:**
/// - [DateTimeUtils]: Localized display formats with `intl`
/// - [DateTimeConverter]: ISO 8601 serialization for Firestore/data layer
class DateFormatter {
  static String getTimeRemaining(DateTime? dueDate) {
    if (dueDate == null) {
      return 'No due date';
    }

    final now = DateTime.now();
    if (dueDate.isBefore(now)) {
      return 'Overdue';
    }

    final difference = dueDate.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} left';
    }

    if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} left';
    }

    if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} left';
    }

    return '${difference.inSeconds} ${difference.inSeconds == 1 ? 'second' : 'seconds'} left';
  }

  static String formatChatTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDay = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDay == today) {
      final hour = timestamp.hour == 0
          ? 12
          : (timestamp.hour > 12 ? timestamp.hour - 12 : timestamp.hour);
      final period = timestamp.hour < 12 ? 'AM' : 'PM';
      return '${hour.toString()}:${timestamp.minute.toString().padLeft(2, '0')} $period';
    } else if (messageDay == yesterday) {
      return 'Yesterday';
    } else if (now.difference(timestamp).inDays < 7) {
      const days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return days[timestamp.weekday - 1];
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  static Color getDueDateColor(DateTime? dueDate) {
    if (dueDate == null) {
      return const Color(0xFF9E9E9E);
    }

    final now = DateTime.now();

    if (dueDate.isBefore(now)) {
      return const Color(0xFFE53935);
    }

    final difference = dueDate.difference(now);

    if (difference.inHours < 24) {
      return const Color(0xFFFF9800);
    }

    if (difference.inDays < 3) {
      return const Color(0xFFFFC107);
    }

    return const Color(0xFF4CAF50);
  }

  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  static String formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour == 0
        ? 12
        : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final period = dateTime.hour < 12 ? 'AM' : 'PM';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${hour.toString()}:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }

  /// Formats a date in ISO 8601 format (YYYY-MM-DD).
  ///
  /// This format is suitable for YAML serialization and Firestore storage.
  static String formatIsoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// Formats a duration as "Xh Xm" or "Xm Xs" depending on length.
  /// For durations over an hour: "2h 15m"
  /// For durations under an hour: "15m 30s"
  /// For durations under a minute: "30s"
  static String formatElapsedTime(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  /// Formats a duration compactly as "H:MM" or "M:SS".
  /// For durations over an hour: "2:15" (hours:minutes)
  /// For durations under an hour: "15:30" (minutes:seconds)
  static String formatElapsedTimeCompact(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}:${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}';
    } else {
      return '${duration.inMinutes}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    }
  }
}
