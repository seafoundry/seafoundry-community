// @tier: community

// Utility functions for string formatting and transformation.

/// Capitalizes the first letter of [input], leaving the rest unchanged.
/// Returns empty string if input is empty.
String capitalize(String input) {
  if (input.isEmpty) return input;
  return input[0].toUpperCase() + input.substring(1);
}

/// Converts a snake_case string to Title Case.
///
/// Example:
/// ```dart
/// formatSnakeCaseToTitleCase('settlement_substrate') // Returns 'Settlement Substrate'
/// formatSnakeCaseToTitleCase('hello_world') // Returns 'Hello World'
/// formatSnakeCaseToTitleCase('single') // Returns 'Single'
/// ```
String formatSnakeCaseToTitleCase(String value) {
  return value
      .split('_')
      .map((word) => word.isEmpty
          ? ''
          : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
      .join(' ');
}

/// Converts a string to a URL-safe slug for use in IDs.
///
/// - Converts to lowercase
/// - Replaces non-alphanumeric characters with hyphens
/// - Removes consecutive hyphens
/// - Trims leading/trailing hyphens
/// - Returns [fallback] if result would be empty
///
/// Example:
/// ```dart
/// slug('Hello World!') // Returns 'hello-world'
/// slug('Test--Value') // Returns 'test-value'
/// slug('', fallback: 'default') // Returns 'default'
/// ```
String slug(String value, {String fallback = 'value'}) {
  if (value.isEmpty) return fallback;

  final result = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  return result.isEmpty ? fallback : result;
}
