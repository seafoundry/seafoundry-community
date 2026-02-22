// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/permits/deliverable.dart';

/// State for the Deliverables tab in ReportingHub
class DeliverablesTabState extends Equatable {
  final List<Deliverable> deliverables;
  final bool loading;
  final String? errorMessage;

  /// Currently selected status filter (null = show all)
  final DeliverableStatus? statusFilter;

  const DeliverablesTabState({
    this.deliverables = const [],
    this.loading = false,
    this.errorMessage,
    this.statusFilter,
  });

  /// Get filtered deliverables based on current status filter
  List<Deliverable> get filteredDeliverables {
    if (statusFilter == null) return deliverables;
    return deliverables.where((d) => d.status == statusFilter).toList();
  }

  DeliverablesTabState copyWith({
    List<Deliverable>? deliverables,
    bool? loading,
    String? errorMessage,
    DeliverableStatus? statusFilter,
    bool clearStatusFilter = false,
  }) {
    return DeliverablesTabState(
      deliverables: deliverables ?? this.deliverables,
      loading: loading ?? this.loading,
      errorMessage: errorMessage,
      statusFilter: clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
    );
  }

  @override
  List<Object?> get props => [deliverables, loading, errorMessage, statusFilter];
}
