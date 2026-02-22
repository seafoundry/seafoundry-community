// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/operations/funder.dart';
import 'package:seafoundry_app/models/permits/deliverable.dart';

/// State for the Funders tab in ReportingHub
class FundersTabState extends Equatable {
  final List<Funder> funders;
  final bool loading;
  final String? errorMessage;

  /// Set of expanded funder IDs (for ExpansionTile state)
  final Set<String> expandedFunderIds;

  /// Deliverables keyed by funder ID (loaded on expansion)
  final Map<String, List<Deliverable>> funderDeliverables;

  /// Set of funder IDs currently loading deliverables
  final Set<String> loadingDeliverables;

  const FundersTabState({
    this.funders = const [],
    this.loading = false,
    this.errorMessage,
    this.expandedFunderIds = const {},
    this.funderDeliverables = const {},
    this.loadingDeliverables = const {},
  });

  FundersTabState copyWith({
    List<Funder>? funders,
    bool? loading,
    String? errorMessage,
    Set<String>? expandedFunderIds,
    Map<String, List<Deliverable>>? funderDeliverables,
    Set<String>? loadingDeliverables,
  }) {
    return FundersTabState(
      funders: funders ?? this.funders,
      loading: loading ?? this.loading,
      errorMessage: errorMessage,
      expandedFunderIds: expandedFunderIds ?? this.expandedFunderIds,
      funderDeliverables: funderDeliverables ?? this.funderDeliverables,
      loadingDeliverables: loadingDeliverables ?? this.loadingDeliverables,
    );
  }

  /// Check if a funder is expanded
  bool isExpanded(String funderId) => expandedFunderIds.contains(funderId);

  /// Check if deliverables are loading for a funder
  bool isLoadingDeliverables(String funderId) =>
      loadingDeliverables.contains(funderId);

  /// Get deliverables for a funder (empty list if not loaded)
  List<Deliverable> getDeliverables(String funderId) =>
      funderDeliverables[funderId] ?? const [];

  @override
  List<Object?> get props => [
        funders,
        loading,
        errorMessage,
        expandedFunderIds,
        funderDeliverables,
        loadingDeliverables,
      ];
}
