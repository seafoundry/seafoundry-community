// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/permits/permit.dart';

/// State for the Permits tab in ReportingHub
class PermitsTabState extends Equatable {
  final List<Permit> permits;
  final bool loading;
  final String? errorMessage;

  const PermitsTabState({
    this.permits = const [],
    this.loading = false,
    this.errorMessage,
  });

  PermitsTabState copyWith({
    List<Permit>? permits,
    bool? loading,
    String? errorMessage,
  }) {
    return PermitsTabState(
      permits: permits ?? this.permits,
      loading: loading ?? this.loading,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [permits, loading, errorMessage];
}
