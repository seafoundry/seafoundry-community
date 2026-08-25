part of 'inventory_spreadsheet_cubit.dart';

/// State for the inventory spreadsheet view.
///
/// Design note: [filteredRows] is stored separately from [allRows] rather than
/// computed as a getter because:
/// 1. Equatable state requires stored fields for proper equality comparison
/// 2. The cubit's [_emitWithRecalculated] ensures filteredRows is always updated
///    when allRows or filters change
/// 3. Available filter options (availableSites, etc.) are also derived from allRows
///    and follow the same pattern
class InventorySpreadsheetState extends Equatable {
  const InventorySpreadsheetState({
    required this.isInitializing,
    required this.isRefreshing,
    required this.allRows,
    required this.filteredRows,
    required this.siteFilter,
    required this.speciesFilter,
    required this.availableSites,
    required this.availableSpecies,
    required this.reloadToken,
    required this.errorMessage,
  });

  final bool isInitializing;
  final bool isRefreshing;

  /// Raw inventory data before filtering.
  final List<Map<String, dynamic>> allRows;

  /// Filtered view of [allRows] based on current filter settings.
  /// Always updated by cubit when allRows or filters change.
  final List<Map<String, dynamic>> filteredRows;
  final String? siteFilter;
  final String? speciesFilter;
  final List<String> availableSites;
  final List<String> availableSpecies;
  final int reloadToken;
  final String? errorMessage;

  static const Object _unset = Object();

  factory InventorySpreadsheetState.initial() =>
      const InventorySpreadsheetState(
        isInitializing: true,
        isRefreshing: false,
        allRows: <Map<String, dynamic>>[],
        filteredRows: <Map<String, dynamic>>[],
        siteFilter: null,
        speciesFilter: null,
        availableSites: <String>[],
        availableSpecies: <String>[],
        reloadToken: 0,
        errorMessage: null,
      );

  InventorySpreadsheetState copyWith({
    bool? isInitializing,
    bool? isRefreshing,
    List<Map<String, dynamic>>? allRows,
    List<Map<String, dynamic>>? filteredRows,
    Object? siteFilter = _unset,
    Object? speciesFilter = _unset,
    List<String>? availableSites,
    List<String>? availableSpecies,
    int? reloadToken,
    Object? errorMessage = _unset,
  }) {
    return InventorySpreadsheetState(
      isInitializing: isInitializing ?? this.isInitializing,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      allRows: allRows ?? this.allRows,
      filteredRows: filteredRows ?? this.filteredRows,
      siteFilter:
          siteFilter == _unset ? this.siteFilter : siteFilter as String?,
      speciesFilter: speciesFilter == _unset
          ? this.speciesFilter
          : speciesFilter as String?,
      availableSites: availableSites ?? this.availableSites,
      availableSpecies: availableSpecies ?? this.availableSpecies,
      reloadToken: reloadToken ?? this.reloadToken,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  @override
  List<Object?> get props => [
        isInitializing,
        isRefreshing,
        allRows,
        filteredRows,
        siteFilter,
        speciesFilter,
        availableSites,
        availableSpecies,
        reloadToken,
        errorMessage,
      ];
}
