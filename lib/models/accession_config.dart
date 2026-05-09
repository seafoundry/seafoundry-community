// @tier: community
import 'package:equatable/equatable.dart';

/// Configuration for auto-generating accession numbers within an organization.
///
/// Accession numbers follow the pattern `{prefix}{paddedSequence}`, e.g.
/// `TFA-0001`. The [nextSequence] is atomically incremented via Firestore
/// transaction each time a new number is generated.
class AccessionConfig extends Equatable {
  const AccessionConfig({
    this.enabled = false,
    this.prefix = '',
    this.digitCount = 4,
    this.nextSequence = 1,
  });

  final bool enabled;
  final String prefix;
  final int digitCount;
  final int nextSequence;

  factory AccessionConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AccessionConfig();
    return AccessionConfig(
      enabled: json['enabled'] as bool? ?? false,
      prefix: json['prefix'] as String? ?? '',
      digitCount: (json['digitCount'] as int? ?? 4).clamp(1, 10),
      nextSequence: json['nextSequence'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'prefix': prefix,
        'digitCount': digitCount,
        'nextSequence': nextSequence,
      };

  /// Formats the next accession number (e.g., "TFA-0001").
  String formatNext() {
    final seq = nextSequence.toString().padLeft(digitCount, '0');
    return prefix.isEmpty ? seq : '$prefix$seq';
  }

  AccessionConfig copyWith({
    bool? enabled,
    String? prefix,
    int? digitCount,
    int? nextSequence,
  }) =>
      AccessionConfig(
        enabled: enabled ?? this.enabled,
        prefix: prefix ?? this.prefix,
        digitCount: digitCount ?? this.digitCount,
        nextSequence: nextSequence ?? this.nextSequence,
      );

  @override
  List<Object?> get props => [enabled, prefix, digitCount, nextSequence];
}
