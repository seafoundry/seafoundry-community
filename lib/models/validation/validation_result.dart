// @tier: community
enum ValidationSeverity { info, warning, error }

class ValidationResult {
  const ValidationResult._(this.isValid, this.message, this.severity);

  const ValidationResult.valid() : this._(true, null, ValidationSeverity.info);

  const ValidationResult.invalid({
    required String message,
    ValidationSeverity severity = ValidationSeverity.error,
  }) : this._(false, message, severity);

  final bool isValid;
  final String? message;
  final ValidationSeverity severity;
}
