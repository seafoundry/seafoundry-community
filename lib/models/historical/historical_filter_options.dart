// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Available filter options for historical data.
/// Derived from the historical dataset to provide UI filter choices.
class HistoricalFilterOptions extends Equatable {
  const HistoricalFilterOptions({
    this.reefs = const [],
    this.regions = const [],
    this.species = const [],
  });

  /// Available reefs for filtering
  final List<FilterOption> reefs;

  /// Available regions for filtering
  final List<FilterOption> regions;

  /// Available species for filtering
  final List<FilterOption> species;

  factory HistoricalFilterOptions.fromJson(Map<String, dynamic> json) {
    return HistoricalFilterOptions(
      reefs: json['reefs'] is List
          ? (json['reefs'] as List)
              .whereType<Map<String, dynamic>>()
              .map((item) => FilterOption.fromJson(item))
              .toList()
          : const [],
      regions: json['regions'] is List
          ? (json['regions'] as List)
              .whereType<Map<String, dynamic>>()
              .map((item) => FilterOption.fromJson(item))
              .toList()
          : const [],
      species: json['species'] is List
          ? (json['species'] as List)
              .whereType<Map<String, dynamic>>()
              .map((item) => FilterOption.fromJson(item))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reefs': reefs.map((r) => r.toJson()).toList(),
      'regions': regions.map((r) => r.toJson()).toList(),
      'species': species.map((s) => s.toJson()).toList(),
    };
  }

  HistoricalFilterOptions copyWith({
    List<FilterOption>? reefs,
    List<FilterOption>? regions,
    List<FilterOption>? species,
  }) {
    return HistoricalFilterOptions(
      reefs: reefs ?? this.reefs,
      regions: regions ?? this.regions,
      species: species ?? this.species,
    );
  }

  @override
  List<Object?> get props => [reefs, regions, species];
}

/// A single filter option with ID and display name.
class FilterOption extends Equatable {
  const FilterOption({
    required this.id,
    required this.name,
    this.count = 0,
  });

  /// Unique identifier (reef ID, region ID, species ID)
  final String id;

  /// Display name
  final String name;

  /// Optional count of items in this category
  final int count;

  factory FilterOption.fromJson(Map<String, dynamic> json) {
    return FilterOption(
      id: json['id'] as String,
      name: json['name'] as String,
      count: safeInt(json['count']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'count': count,
    };
  }

  FilterOption copyWith({
    String? id,
    String? name,
    int? count,
  }) {
    return FilterOption(
      id: id ?? this.id,
      name: name ?? this.name,
      count: count ?? this.count,
    );
  }

  @override
  List<Object?> get props => [id, name, count];
}
