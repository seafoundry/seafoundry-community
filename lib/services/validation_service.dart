// @tier: community
import 'package:flutter/services.dart';

/// Centralized validation service for consistent validation across the app
///
/// This service provides:
/// - Common validation rules
/// - Custom validators
/// - Input formatters
/// - Error messages
///
/// Usage:
/// ```dart
/// TextFormField(
///   validator: ValidationService.required('Email'),
///   inputFormatters: [ValidationService.emailFormatter],
/// );
/// ```
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

  /// Email validator
  static String? email(String? value) {
    if (value == null || value.isEmpty) return null;

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  /// Phone number validator
  static String? phoneNumber(String? value) {
    if (value == null || value.isEmpty) return null;

    // Remove all non-digits
    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.length < 10) {
      return 'Phone number must be at least 10 digits';
    }
    return null;
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

  /// Percentage validator (0-100)
  static String? percentage(String? value) {
    if (value == null || value.isEmpty) return null;

    final number = double.tryParse(value);
    if (number == null) {
      return 'Please enter a valid percentage';
    }

    if (number < 0 || number > 100) {
      return 'Percentage must be between 0 and 100';
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

  /// URL validator
  static String? url(String? value) {
    if (value == null || value.isEmpty) return null;

    try {
      final uri = Uri.parse(value);
      if (!uri.hasScheme || !uri.hasAuthority) {
        return 'Please enter a valid URL';
      }
      return null;
    } catch (_) {
      return 'Please enter a valid URL';
    }
  }

  /// Date validator
  static String? Function(String?) date({
    DateTime? minDate,
    DateTime? maxDate,
    DateTime? notBefore,
    DateTime? notAfter,
  }) {
    return (value) {
      if (value == null || value.isEmpty) return null;

      final isoLikePattern = RegExp(r'^\d{4}-\d{2}-\d{2}');
      if (!isoLikePattern.hasMatch(value.trim())) {
        return 'Please enter a valid date';
      }

      DateTime date;
      try {
        date = DateTime.parse(value);
      } catch (_) {
        return 'Please enter a valid date';
      }

      if (minDate != null && date.isBefore(minDate)) {
        return 'Date cannot be before ${_formatDate(minDate)}';
      }

      if (maxDate != null && date.isAfter(maxDate)) {
        return 'Date cannot be after ${_formatDate(maxDate)}';
      }

      if (notBefore != null && date.isBefore(notBefore)) {
        return 'Date must be after ${_formatDate(notBefore)}';
      }

      if (notAfter != null && date.isAfter(notAfter)) {
        return 'Date must be before ${_formatDate(notAfter)}';
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

  /// Conditional validator
  static String? Function(String?) when({
    required bool Function() condition,
    required String? Function(String?) validator,
  }) {
    return (value) {
      if (condition()) {
        return validator(value);
      }
      return null;
    };
  }

  // ===== Input Formatters =====

  /// Uppercase formatter
  static final uppercaseFormatter = TextInputFormatter.withFunction(
    (oldValue, newValue) => TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    ),
  );

  /// Lowercase formatter
  static final lowercaseFormatter = TextInputFormatter.withFunction(
    (oldValue, newValue) => TextEditingValue(
      text: newValue.text.toLowerCase(),
      selection: newValue.selection,
    ),
  );

  /// Numeric only formatter
  static final numericFormatter = FilteringTextInputFormatter.digitsOnly;

  /// Decimal formatter
  static final decimalFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'^\d*\.?\d*'),
  );

  /// Alphanumeric formatter
  static final alphanumericFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[a-zA-Z0-9]'),
  );

  /// No spaces formatter
  static final noSpacesFormatter = FilteringTextInputFormatter.deny(' ');

  /// Email formatter (lowercase, no spaces)
  static final emailFormatter = TextInputFormatter.withFunction((
    oldValue,
    newValue,
  ) {
    final text = newValue.text.toLowerCase().replaceAll(' ', '');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  });

  /// Phone formatter (formats as user types)
  static final phoneFormatter = TextInputFormatter.withFunction((
    oldValue,
    newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length && i < 10; i++) {
      if (i == 3 || i == 6) buffer.write('-');
      buffer.write(text[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  });

  /// Provenance ID formatter
  static final provenanceIdFormatter = TextInputFormatter.withFunction((
    oldValue,
    newValue,
  ) {
    var text = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (text.isEmpty) {
      return newValue;
    }

    String prefix;
    if (text.startsWith('PID')) {
      prefix = 'PID';
      text = text.substring(3);
    } else if (text.startsWith('SF')) {
      prefix = 'SF';
      text = text.substring(2);
    } else {
      prefix = 'PID';
    }

    final buffer = StringBuffer(prefix);
    if (text.isNotEmpty) {
      buffer.write('-');
      for (int i = 0; i < text.length && i < 8; i++) {
        if (i == 4) buffer.write('-');
        buffer.write(text[i]);
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  });

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

  /// Tag validator
  static String? tag(String? value) {
    if (value == null || value.isEmpty) return null;

    return combine([
      length(max: 20, fieldName: 'Tag'),
      pattern(
        regex: RegExp(r'^[A-Z0-9\-]+$'),
        message: 'Tag must be uppercase letters, numbers, and hyphens only',
      ),
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

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // ===== Error Messages =====

  static const String genericRequired = 'This field is required';
  static const String invalidEmail = 'Please enter a valid email address';
  static const String invalidPhone = 'Please enter a valid phone number';
  static const String invalidNumber = 'Please enter a valid number';
  static const String invalidDate = 'Please enter a valid date';
  static const String invalidUrl = 'Please enter a valid URL';
}
