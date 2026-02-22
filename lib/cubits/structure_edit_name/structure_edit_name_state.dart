// @tier: community
import 'package:equatable/equatable.dart';

/// State for StructureEditNameDialog
class StructureEditNameState extends Equatable {
  final String name;
  final String? errorMessage;
  final bool loading;

  const StructureEditNameState({
    required this.name,
    this.errorMessage,
    this.loading = false,
  });

  StructureEditNameState copyWith({
    String? name,
    String? errorMessage,
    bool? loading,
  }) {
    return StructureEditNameState(
      name: name ?? this.name,
      errorMessage: errorMessage ?? this.errorMessage,
      loading: loading ?? this.loading,
    );
  }

  @override
  List<Object?> get props => [name, errorMessage, loading];
}

