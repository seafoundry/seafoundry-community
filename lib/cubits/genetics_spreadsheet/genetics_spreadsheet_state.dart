part of 'genetics_spreadsheet_cubit.dart';

/// State for the genetics spreadsheet view.
///
/// Design note: [filteredRows] is stored separately from [allRows] rather than
/// computed as a getter because:
/// 1. Equatable state requires stored fields for proper equality comparison
/// 2. The cubit's [_emitWithRecalculated] ensures filteredRows is always updated
///    when allRows or filters change
/// 3. Available filter options (availableSites, etc.) are also derived from allRows
///    and follow the same pattern
class GeneticsSpreadsheetState extends Equatable {
  const GeneticsSpreadsheetState({
    required this.isInitializing,
    required this.isRefreshing,
    required this.includeInactive,
    required this.includeArchived,
    required this.errorMessage,
    required this.allRows,
    required this.filteredRows,
    required this.structureFilter,
    required this.siteFilter,
    required this.speciesFilter,
    required this.genetFilter,
    required this.provenanceTypeFilter,
    required this.dateRange,
    required this.availableStructures,
    required this.availableSites,
    required this.availableSpecies,
    required this.availableGenets,
    required this.availableProvenanceTypes,
    required this.reloadToken,
    required this.organismFilter,
  });

  final bool isInitializing;
  final bool isRefreshing;
  final bool includeInactive;
  final bool includeArchived;
  final String? errorMessage;

  /// Raw genetics data before filtering.
  final List<Map<String, dynamic>> allRows;

  /// Filtered view of [allRows] based on current filter settings.
  /// Always updated by cubit when allRows or filters change.
  final List<Map<String, dynamic>> filteredRows;
  final String? structureFilter;
  final String? siteFilter;
  final String? speciesFilter;
  final String? genetFilter;
  final String? provenanceTypeFilter;
  final DateTimeRange? dateRange;
  final List<String> availableStructures;
  final List<String> availableSites;
  final List<String> availableSpecies;
  final List<String> availableGenets;
  final List<String> availableProvenanceTypes;
  final int reloadToken;
  final OrganismKind organismFilter;

  static const Object _unset = Object();

  factory GeneticsSpreadsheetState.initial({
    OrganismKind organismFilter = OrganismKind.coral,
  }) => GeneticsSpreadsheetState(
        isInitializing: true,
        isRefreshing: false,
        includeInactive: false,
        includeArchived: false,
        errorMessage: null,
        allRows: const <Map<String, dynamic>>[],
        filteredRows: const <Map<String, dynamic>>[],
        structureFilter: null,
        siteFilter: null,
        speciesFilter: null,
        genetFilter: null,
        provenanceTypeFilter: null,
        dateRange: null,
        availableStructures: const <String>[],
        availableSites: const <String>[],
        availableSpecies: const <String>[],
        availableGenets: const <String>[],
        availableProvenanceTypes: const <String>[],
        reloadToken: 0,
        organismFilter: organismFilter,
      );

  GeneticsSpreadsheetState copyWith({
    bool? isInitializing,
    bool? isRefreshing,
    bool? includeInactive,
    bool? includeArchived,
    Object? errorMessage = _unset,
    List<Map<String, dynamic>>? allRows,
    List<Map<String, dynamic>>? filteredRows,
    Object? structureFilter = _unset,
    Object? siteFilter = _unset,
    Object? speciesFilter = _unset,
    Object? genetFilter = _unset,
    Object? provenanceTypeFilter = _unset,
    Object? dateRange = _unset,
    List<String>? availableStructures,
    List<String>? availableSites,
    List<String>? availableSpecies,
    List<String>? availableGenets,
    List<String>? availableProvenanceTypes,
    int? reloadToken,
    Object? organismFilter = _unset,
  }) {
    return GeneticsSpreadsheetState(
      isInitializing: isInitializing ?? this.isInitializing,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      includeInactive: includeInactive ?? this.includeInactive,
      includeArchived: includeArchived ?? this.includeArchived,
      errorMessage:
          errorMessage == _unset ? this.errorMessage : errorMessage as String?,
      allRows: allRows ?? this.allRows,
      filteredRows: filteredRows ?? this.filteredRows,
      structureFilter: structureFilter == _unset
          ? this.structureFilter
          : structureFilter as String?,
      siteFilter:
          siteFilter == _unset ? this.siteFilter : siteFilter as String?,
      speciesFilter: speciesFilter == _unset
          ? this.speciesFilter
          : speciesFilter as String?,
      genetFilter:
          genetFilter == _unset ? this.genetFilter : genetFilter as String?,
      provenanceTypeFilter: provenanceTypeFilter == _unset
          ? this.provenanceTypeFilter
          : provenanceTypeFilter as String?,
      dateRange:
          dateRange == _unset ? this.dateRange : dateRange as DateTimeRange?,
      availableStructures: availableStructures ?? this.availableStructures,
      availableSites: availableSites ?? this.availableSites,
      availableSpecies: availableSpecies ?? this.availableSpecies,
      availableGenets: availableGenets ?? this.availableGenets,
      availableProvenanceTypes:
          availableProvenanceTypes ?? this.availableProvenanceTypes,
      reloadToken: reloadToken ?? this.reloadToken,
      organismFilter: organismFilter == _unset
          ? this.organismFilter
          : organismFilter as OrganismKind,
    );
  }

  @override
  List<Object?> get props => [
        isInitializing,
        isRefreshing,
        includeInactive,
        includeArchived,
        errorMessage,
        allRows,
        filteredRows,
        structureFilter,
        siteFilter,
        speciesFilter,
        genetFilter,
        provenanceTypeFilter,
        dateRange,
        availableStructures,
        availableSites,
        availableSpecies,
        availableGenets,
        availableProvenanceTypes,
        reloadToken,
        organismFilter,
      ];
}
