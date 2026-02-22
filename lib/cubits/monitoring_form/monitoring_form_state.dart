// @tier: community
part of 'monitoring_form_cubit.dart';

enum MonitoringFormSubmissionStatus { initial, submitting, success, failure }

class MonitoringFormState extends Equatable {
  const MonitoringFormState({
    this.selectedHealthStatus,
    this.notes = '',
    this.tag = '',
    this.submissionStatus = MonitoringFormSubmissionStatus.initial,
    this.errorMessage,
  });

  final HealthStatus? selectedHealthStatus;
  final String notes;
  final String tag;
  final MonitoringFormSubmissionStatus submissionStatus;
  final String? errorMessage;

  MonitoringFormState copyWith({
    HealthStatus? selectedHealthStatus,
    String? notes,
    String? tag,
    MonitoringFormSubmissionStatus? submissionStatus,
    String? errorMessage,
  }) {
    return MonitoringFormState(
      selectedHealthStatus: selectedHealthStatus ?? this.selectedHealthStatus,
      notes: notes ?? this.notes,
      tag: tag ?? this.tag,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    selectedHealthStatus,
    notes,
    tag,
    submissionStatus,
    errorMessage,
  ];
}
