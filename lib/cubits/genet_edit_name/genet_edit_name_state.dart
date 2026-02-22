// @tier: community
import 'package:equatable/equatable.dart';

class GenetEditNameState extends Equatable {
  const GenetEditNameState({
    required this.name,
    this.loading = false,
    this.errorMessage,
  });

  final String name;
  final bool loading;
  final String? errorMessage;

  @override
  List<Object?> get props => [name, loading, errorMessage];

  GenetEditNameState copyWith({
    String? name,
    bool? loading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return GenetEditNameState(
      name: name ?? this.name,
      loading: loading ?? this.loading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
