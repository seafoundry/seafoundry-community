import 'package:equatable/equatable.dart';

class OrganismAlias extends Equatable {
  const OrganismAlias({
    required this.sourceSystem,
    required this.value,
    this.label,
    this.isPrimary = false,
  });

  final String sourceSystem;
  final String value;
  final String? label;
  final bool isPrimary;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sourceSystem': sourceSystem,
    'value': value,
    if (label != null) 'label': label,
    if (isPrimary) 'isPrimary': true,
  };

  factory OrganismAlias.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      throw ArgumentError.notNull('json');
    }
    final rawSource =
        json['sourceSystem'] ?? json['source'] ?? json['system'] ?? 'custom';
    final rawValue = json['value'] ?? json['label'] ?? '';
    return OrganismAlias(
      sourceSystem: rawSource.toString().trim(),
      value: rawValue.toString().trim(),
      label: json['label']?.toString(),
      isPrimary: json['isPrimary'] == true,
    );
  }

  static List<OrganismAlias> listFromJson(dynamic raw) {
    if (raw is! Iterable) return const <OrganismAlias>[];
    final entries = <OrganismAlias>[];
    for (final item in raw) {
      if (item is OrganismAlias) {
        entries.add(item);
        continue;
      }
      if (item is Map<String, dynamic>) {
        entries.add(OrganismAlias.fromJson(item));
        continue;
      }
      if (item is String) {
        entries.add(
          OrganismAlias(
            sourceSystem: 'custom',
            value: item.trim(),
            label: item,
          ),
        );
      }
    }
    return List<OrganismAlias>.unmodifiable(entries);
  }

  @override
  List<Object?> get props => [sourceSystem, value, label, isPrimary];
}

class ForeignKeyReference extends Equatable {
  const ForeignKeyReference({
    required this.id,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    if (metadata.isNotEmpty) 'metadata': Map<String, dynamic>.from(metadata),
  };

  factory ForeignKeyReference.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      throw ArgumentError.notNull('json');
    }
    Map<String, dynamic> parseMetadata(dynamic value) {
      if (value == null) return const {};
      if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
      if (value is Map) return Map<String, dynamic>.from(value);
      return const {};
    }
    return ForeignKeyReference(
      id: json['id']?.toString() ?? '',
      metadata: parseMetadata(json['metadata']),
    );
  }

  @override
  List<Object?> get props => [id, metadata];
}
