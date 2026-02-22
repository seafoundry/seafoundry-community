// @tier: community
/// Support status for seeding execution environment
class SeedingSupportStatus {
  const SeedingSupportStatus({
    required this.hasDart,
    required this.hasScripts,
    this.dartExecutable,
  });

  final bool hasDart;
  final bool hasScripts;
  final String? dartExecutable;

  bool get isReady => hasDart && hasScripts;
}

/// Field types for seeding dialog form fields
enum SeedingFieldType { text, textarea, bool }

/// Configuration for a seeding dialog form field
class SeedingFieldConfig {
  const SeedingFieldConfig({
    required this.key,
    this.flagName,
    required this.label,
    this.helper,
    this.placeholder,
    this.required = false,
    this.advanced = false,
    this.type = SeedingFieldType.text,
    this.initialValue,
    this.initialBool = false,
    this.omitWhenFalse = true,
    this.flagOnly = false,
    this.isVisible,
  });

  final String key;
  final String? flagName;
  final String label;
  final String? helper;
  final String? placeholder;
  final bool required;
  final bool advanced;
  final SeedingFieldType type;
  final String? initialValue;
  final bool initialBool;
  final bool omitWhenFalse;
  final bool flagOnly;
  final bool Function(Map<String, bool> values)? isVisible;

  bool get isBoolean => type == SeedingFieldType.bool;
}

/// Configuration for a seeding command
class SeedingCommandConfig {
  const SeedingCommandConfig({
    required this.executable,
    required this.scriptPath,
    required this.fields,
  }) : supportsExecution = true;

  const SeedingCommandConfig.unsupported()
      : executable = '',
        scriptPath = '',
        fields = const [],
        supportsExecution = false;

  final String executable;
  final String scriptPath;
  final List<SeedingFieldConfig> fields;
  final bool supportsExecution;
}
