import 'package:equatable/equatable.dart';

/// User's column preferences for a single spreadsheet type.
class ColumnPreferences extends Equatable {
  const ColumnPreferences({
    this.columnOrder = const [],
    this.hiddenColumns = const {},
  });

  /// Ordered list of column keys. Empty means use factory defaults.
  final List<String> columnOrder;

  /// Set of column keys to hide.
  final Set<String> hiddenColumns;

  bool get hasCustomOrder => columnOrder.isNotEmpty;

  factory ColumnPreferences.fromJson(Map<String, dynamic> json) {
    return ColumnPreferences(
      columnOrder: (json['columnOrder'] as List<dynamic>?)?.cast<String>() ??
          const [],
      hiddenColumns: (json['hiddenColumns'] as List<dynamic>?)
              ?.cast<String>()
              .toSet() ??
          const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'columnOrder': columnOrder,
        'hiddenColumns': hiddenColumns.toList(),
      };

  ColumnPreferences copyWith({
    List<String>? columnOrder,
    Set<String>? hiddenColumns,
  }) {
    return ColumnPreferences(
      columnOrder: columnOrder ?? this.columnOrder,
      hiddenColumns: hiddenColumns ?? this.hiddenColumns,
    );
  }

  @override
  List<Object?> get props => [columnOrder, hiddenColumns];
}
