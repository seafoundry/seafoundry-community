// @tier: community
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateRangePreset {
  const DateRangePreset({required this.days, required this.label});

  final int days;
  final String label;
}

class DateRangePresets {
  static const List<DateRangePreset> quickFilters = [
    DateRangePreset(days: 7, label: '7d'),
    DateRangePreset(days: 30, label: '30d'),
    DateRangePreset(days: 60, label: '60d'),
    DateRangePreset(days: 90, label: '90d'),
    DateRangePreset(days: 180, label: '180d'),
    DateRangePreset(days: 365, label: '1year'),
  ];

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  static DateTimeRange normalize(DateTimeRange range) {
    return DateTimeRange(
      start: startOfDay(range.start),
      end: endOfDay(range.end),
    );
  }

  static DateTimeRange rangeForPreset(
    DateRangePreset preset, {
    DateTime? now,
  }) {
    final anchor = startOfDay(now ?? DateTime.now());
    final start = anchor.subtract(Duration(days: preset.days - 1));
    return DateTimeRange(start: start, end: endOfDay(anchor));
  }

  static int rangeLengthInDays(DateTimeRange range) {
    final normalized = normalize(range);
    return normalized.end.difference(normalized.start).inDays + 1;
  }

  static bool isWithinRange(DateTime? date, DateTimeRange range) {
    if (date == null) return false;
    final normalized = startOfDay(date);
    final target = normalize(range);
    return !normalized.isBefore(target.start) &&
        !normalized.isAfter(target.end);
  }

  static bool matchesPreset(
    DateTimeRange? range,
    DateRangePreset preset, {
    DateTime? now,
  }) {
    if (range == null) return false;
    final candidate = normalize(range);
    final presetRange = normalize(rangeForPreset(preset, now: now));
    return candidate.start == presetRange.start &&
        candidate.end == presetRange.end;
  }

  static DateTimeRange previousRange(DateTimeRange range) {
    final length = rangeLengthInDays(range);
    final normalized = normalize(range);
    final prevEnd = normalized.start.subtract(const Duration(days: 1));
    final prevStart = prevEnd.subtract(Duration(days: length - 1));
    return DateTimeRange(start: startOfDay(prevStart), end: endOfDay(prevEnd));
  }

  static String labelForRange(
    DateTimeRange? range, {
    String emptyLabel = 'Date Range',
    DateFormat? formatter,
  }) {
    if (range == null) return emptyLabel;
    final format = formatter ?? DateFormat('MMM d, yyyy');
    return '${format.format(range.start)} – ${format.format(range.end)}';
  }
}
