// @tier: community
import 'package:equatable/equatable.dart';

/// State for ReviewCommitRibbon widget
class ReviewCommitRibbonState extends Equatable {
  final Set<String> committing;

  const ReviewCommitRibbonState({this.committing = const {}});

  ReviewCommitRibbonState copyWith({Set<String>? committing}) {
    return ReviewCommitRibbonState(
      committing: committing ?? this.committing,
    );
  }

  @override
  List<Object?> get props => [committing];
}

