import 'package:equatable/equatable.dart';

/// Captures the taxonomic hierarchy for a species so we can group organisms
/// with shared physical form/propagation patterns.
class OrganismClassification extends Equatable {
  const OrganismClassification({
    this.kingdom,
    this.phylum,
    this.className,
    this.order,
    this.family,
  });

  final String? kingdom;
  final String? phylum;
  final String? className;
  final String? order;
  final String? family;

  factory OrganismClassification.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const OrganismClassification();
    return OrganismClassification(
      kingdom: _read(json, 'kingdom'),
      phylum: _read(json, 'phylum'),
      className: _read(json, 'class'),
      order: _read(json, 'order'),
      family: _read(json, 'family'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (kingdom != null) 'kingdom': kingdom,
      if (phylum != null) 'phylum': phylum,
      if (className != null) 'class': className,
      if (order != null) 'order': order,
      if (family != null) 'family': family,
    };
  }

  static String? _read(Map<String, dynamic> json, String key) {
    final value = json[key]?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  @override
  List<Object?> get props => [kingdom, phylum, className, order, family];
}
