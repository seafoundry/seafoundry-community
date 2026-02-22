// @tier: community
import 'package:equatable/equatable.dart';

/// State for transfer count cubit
abstract class TransferCountState extends Equatable {
  const TransferCountState();

  @override
  List<Object?> get props => [];
}

/// Initial state when cubit is created
class TransferCountInitial extends TransferCountState {
  const TransferCountInitial();
}

/// State when transfer count is being loaded
class TransferCountLoading extends TransferCountState {
  const TransferCountLoading();
}

/// State when transfer count has been loaded successfully
class TransferCountLoaded extends TransferCountState {
  final int count;

  const TransferCountLoaded(this.count);

  @override
  List<Object?> get props => [count];
}

/// State when there was an error loading transfer count
class TransferCountError extends TransferCountState {
  final String message;

  const TransferCountError(this.message);

  @override
  List<Object?> get props => [message];
}
