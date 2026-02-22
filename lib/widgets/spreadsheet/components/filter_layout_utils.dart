// @tier: community
import 'dart:math' as math;

/// Utility helpers for building responsive spreadsheet filter bars.
///
/// Contains layout calculations for responsive field widths and
/// label formatting utilities for consistent filter dropdown labels.
///
/// Ensures individual filter controls shrink to the available width on
/// smaller screens to avoid RenderFlex overflow while still maintaining the
/// preferred control width on wide layouts.
class FilterLayoutUtils {
  const FilterLayoutUtils._();

  /// Calculates an appropriate width for a filter control given the available
  /// [maxWidth]. Controls will use [preferred] width when space permits and
  /// shrink proportionally when only one or two columns fit within the row.
  static double fieldWidth(
    double maxWidth, {
    double preferred = 180,
    double min = 140,
    double spacing = 16,
  }) {
    if (maxWidth.isInfinite) return preferred;

    final safeMin = math.min(min, maxWidth);
    final safePreferred = math.min(preferred, maxWidth);

    if (maxWidth <= preferred) {
      return math.max(safeMin, safePreferred);
    }

    final twoColumnThreshold = preferred * 2 + spacing;
    if (maxWidth <= twoColumnThreshold) {
      final computed = (maxWidth - spacing) / 2;
      return math.max(safeMin, math.min(computed, safePreferred));
    }

    return safePreferred;
  }

  /// Convenience helper for search inputs or wider dropdowns that prefer a
  /// slightly larger default footprint.
  static double wideFieldWidth(
    double maxWidth, {
    double preferred = 240,
    double min = 160,
    double spacing = 16,
  }) {
    return fieldWidth(
      maxWidth,
      preferred: preferred,
      min: min,
      spacing: spacing,
    );
  }

  /// Formats a raw filter value string into a human-readable label.
  ///
  /// Converts snake_case, camelCase, and mixed formats into Title Case
  /// with proper spacing between words.
  ///
  /// Examples:
  /// - 'provenance_type_wild' -> 'Provenance Type Wild'
  /// - 'sexualCohort' -> 'Sexual Cohort'
  /// - 'SOME_CONSTANT' -> 'Some Constant'
  static String formatFilterLabel(String raw) {
    if (raw.trim().isEmpty) return raw;

    // Replace underscores with spaces and handle camelCase
    final withSpaces = raw.replaceAll(RegExp(r'[_\s]+'), ' ').replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    ).trim();

    // Title case each word
    return withSpaces
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }
}

