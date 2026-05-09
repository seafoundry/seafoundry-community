// @tier: community

/// Centralized validation service for consistent validation across the app
class ValidationService {
  // Private constructor to prevent instantiation
  ValidationService._();

  // ===== Common Validators =====

  /// Required field validator
  static String? Function(String?) required(String fieldName) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return '$fieldName is required';
      }
      return null;
    };
  }

  /// Number range validator
  static String? Function(String?) numberRange({
    double? min,
    double? max,
    String? fieldName,
  }) {
    return (value) {
      if (value == null || value.isEmpty) return null;

      final number = double.tryParse(value);
      if (number == null) {
        return 'Please enter a valid number';
      }

      if (min != null && number < min) {
        return '${fieldName ?? 'Value'} must be at least $min';
      }

      if (max != null && number > max) {
        return '${fieldName ?? 'Value'} must be at most $max';
      }

      return null;
    };
  }

  /// Integer validator
  static String? integer(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) return null;

    final number = int.tryParse(value);
    if (number == null) {
      return '${fieldName ?? 'Value'} must be a whole number';
    }
    return null;
  }

  /// Length validator
  static String? Function(String?) length({
    int? min,
    int? max,
    String? fieldName,
  }) {
    return (value) {
      if (value == null || value.isEmpty) return null;

      if (min != null && value.length < min) {
        return '${fieldName ?? 'Value'} must be at least $min characters';
      }

      if (max != null && value.length > max) {
        return '${fieldName ?? 'Value'} must be at most $max characters';
      }

      return null;
    };
  }

  /// Pattern validator
  static String? Function(String?) pattern({
    required RegExp regex,
    required String message,
  }) {
    return (value) {
      if (value == null || value.isEmpty) return null;

      if (!regex.hasMatch(value)) {
        return message;
      }
      return null;
    };
  }

  /// Alphanumeric validator
  static String? alphanumeric(String? value, {bool allowSpaces = false}) {
    if (value == null || value.isEmpty) return null;

    final pattern = allowSpaces
        ? RegExp(r'^[a-zA-Z0-9\s]+$')
        : RegExp(r'^[a-zA-Z0-9]+$');

    if (!pattern.hasMatch(value)) {
      return allowSpaces
          ? 'Only letters, numbers, and spaces allowed'
          : 'Only letters and numbers allowed';
    }
    return null;
  }

  /// Provenance ID validator (format: PID-XX(XX)-NNNN(+))
  ///
  /// Accepts auto-generated PIDs with 2-4 character species slugs and 4+
  /// digit counters (e.g., PID-AC-0001, PID-ACER-10000). Legacy SF- prefixed
  /// IDs are not supported.
  static String? provenanceId(String? value) {
    if (value == null || value.isEmpty) return null;

    final normalized = value.trim().toUpperCase();
    if (normalized.startsWith('SF-')) {
      return 'Legacy SF- provenance IDs are not supported. Use PID-XXXX-0000.';
    }

    // Species slug: 2-4 alphanumeric chars. Counter: 4+ alphanumeric chars.
    // Matches auto-generated (PID-ACER-0001).
    final provenanceIdRegex = RegExp(r'^PID-[A-Z0-9]{2,4}-[A-Z0-9]{4,}$');

    if (!provenanceIdRegex.hasMatch(normalized)) {
      return 'Invalid Provenance ID format (e.g., PID-ACER-0001)';
    }
    return null;
  }

  // ===== Composite Validators =====

  /// Combine multiple validators
  static String? Function(String?) combine(
    List<String? Function(String?)> validators,
  ) {
    return (value) {
      for (final validator in validators) {
        final error = validator(value);
        if (error != null) return error;
      }
      return null;
    };
  }

  // ===== Record Validators =====

  /// Record name validator
  static String? recordName(String? value) {
    return combine([
      required('Record name'),
      length(min: 3, max: 50, fieldName: 'Record name'),
      pattern(
        regex: RegExp(r'^[a-zA-Z0-9\s\-_]+$'),
        message:
            'Record name can only contain letters, numbers, spaces, hyphens, and underscores',
      ),
    ])(value);
  }

  /// Genet name validator
  static String? genetName(String? value) {
    return combine([
      required('Genet name'),
      length(min: 3, max: 30, fieldName: 'Genet name'),
      (val) => alphanumeric(val, allowSpaces: true),
    ])(value);
  }

  /// Quantity validator
  static String? quantity(String? value, {int? max}) {
    return combine([
      required('Quantity'),
      (val) => integer(val, fieldName: 'Quantity'),
      numberRange(min: 1, max: max?.toDouble() ?? 10000, fieldName: 'Quantity'),
    ])(value);
  }

  /// Size validator (in cm)
  static String? coralSize(String? value) {
    return combine([
      required('Size'),
      decimalNumber,
      numberRange(min: 0.1, max: 1000, fieldName: 'Size'),
    ])(value);
  }

  // ===== Helper Functions =====

  static String? decimalNumber(String? value) {
    if (value == null || value.isEmpty) return null;

    final number = double.tryParse(value);
    if (number == null) {
      return 'Please enter a valid number';
    }
    return null;
  }
}
