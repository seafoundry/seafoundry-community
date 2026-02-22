// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/cubits/structure_capacity_config/structure_capacity_rule_form.dart';

/// State for structure capacity configuration management.
class StructureCapacityConfigState extends Equatable {
  const StructureCapacityConfigState({
    this.isLoading = false,
    this.isSaving = false,
    this.rules = const [],
    this.errorMessage,
    this.saveSuccess = false,
  });

  final bool isLoading;
  final bool isSaving;
  final List<StructureCapacityRuleForm> rules;
  final String? errorMessage;
  final bool saveSuccess;

  StructureCapacityConfigState copyWith({
    bool? isLoading,
    bool? isSaving,
    List<StructureCapacityRuleForm> Function()? rules,
    String? Function()? errorMessage,
    bool? saveSuccess,
  }) {
    return StructureCapacityConfigState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      rules: rules != null ? rules() : this.rules,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      saveSuccess: saveSuccess ?? this.saveSuccess,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isSaving,
        rules,
        errorMessage,
        saveSuccess,
      ];
}
