// @tier: community
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// State for error details widget
class ErrorDetailsState extends Equatable {
  final bool showDetails;

  const ErrorDetailsState({this.showDetails = false});

  ErrorDetailsState copyWith({bool? showDetails}) {
    return ErrorDetailsState(showDetails: showDetails ?? this.showDetails);
  }

  @override
  List<Object?> get props => [showDetails];
}

/// Cubit for managing error details display state
class ErrorDetailsCubit extends Cubit<ErrorDetailsState> {
  ErrorDetailsCubit() : super(const ErrorDetailsState());

  /// Toggle the display of technical details
  void toggleDetails() {
    emit(state.copyWith(showDetails: !state.showDetails));
  }

  /// Show technical details
  void showDetails() {
    emit(state.copyWith(showDetails: true));
  }

  /// Hide technical details
  void hideDetails() {
    emit(state.copyWith(showDetails: false));
  }
}
