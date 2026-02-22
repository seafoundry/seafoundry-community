// @tier: community
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/tour_step.dart';

/// Base state for tour
abstract class TourState extends Equatable {
  const TourState();

  @override
  List<Object?> get props => [];
}

/// Initial state - tour not started
class TourInitial extends TourState {}

/// Tour is in progress
class TourInProgress extends TourState {
  const TourInProgress({
    required this.currentStep,
    required this.currentIndex,
    required this.totalSteps,
  });

  final TourStep currentStep;
  final int currentIndex;
  final int totalSteps;

  @override
  List<Object?> get props => [currentStep.id, currentIndex, totalSteps];
}

/// Tour was skipped
class TourSkipped extends TourState {}

/// Tour completed successfully
class TourComplete extends TourState {}

/// Cubit to manage first-time login tour state
class TourCubit extends Cubit<TourState> {
  TourCubit({
    required this.tourSteps,
  }) : super(TourInitial()) {
    _currentStepIndex = 0;
  }

  final List<TourStep> tourSteps;
  int _currentStepIndex = 0;

  /// Start the tour
  void startTour() {
    if (tourSteps.isEmpty) {
      emit(TourComplete());
      return;
    }
    _currentStepIndex = 0;
    emit(TourInProgress(
      currentStep: tourSteps[_currentStepIndex],
      currentIndex: _currentStepIndex,
      totalSteps: tourSteps.length,
    ));
  }

  /// Move to next step
  void nextStep() {
    if (_currentStepIndex >= tourSteps.length - 1) {
      completeTour();
      return;
    }
    _currentStepIndex++;
    emit(TourInProgress(
      currentStep: tourSteps[_currentStepIndex],
      currentIndex: _currentStepIndex,
      totalSteps: tourSteps.length,
    ));
  }

  /// Move to previous step
  void previousStep() {
    if (_currentStepIndex <= 0) {
      return;
    }
    _currentStepIndex--;
    emit(TourInProgress(
      currentStep: tourSteps[_currentStepIndex],
      currentIndex: _currentStepIndex,
      totalSteps: tourSteps.length,
    ));
  }

  /// Skip the tour
  void skipTour() {
    emit(TourSkipped());
  }

  /// Complete the tour
  void completeTour() {
    emit(TourComplete());
  }

  /// Get current step
  TourStep? get currentStep {
    if (_currentStepIndex < 0 || _currentStepIndex >= tourSteps.length) {
      return null;
    }
    return tourSteps[_currentStepIndex];
  }

  /// Check if tour is in progress
  bool get isInProgress => state is TourInProgress;
}
