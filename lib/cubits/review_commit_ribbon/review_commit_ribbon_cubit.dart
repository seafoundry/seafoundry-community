// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/review_commit_ribbon/review_commit_ribbon_state.dart';

/// Cubit for managing commit state in ReviewCommitRibbon
class ReviewCommitRibbonCubit extends Cubit<ReviewCommitRibbonState> {
  ReviewCommitRibbonCubit() : super(const ReviewCommitRibbonState());

  /// Add a session ID to the committing set
  void addCommitting(String id) {
    emit(state.copyWith(committing: {...state.committing, id}));
  }

  /// Remove a session ID from the committing set
  void removeCommitting(String id) {
    final updated = {...state.committing}..remove(id);
    emit(state.copyWith(committing: updated));
  }

  /// Check if a session is currently being committed
  bool isCommitting(String id) {
    return state.committing.contains(id);
  }
}

