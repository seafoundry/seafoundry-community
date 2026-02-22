// @tier: community
import 'package:equatable/equatable.dart';

enum DeepLinkStatus { idle, handling, navigated, failed }

class DeepLinkState extends Equatable {
  const DeepLinkState({
    this.status = DeepLinkStatus.idle,
    this.lastUri,
    this.errorMessage,
  });

  final DeepLinkStatus status;
  final Uri? lastUri;
  final String? errorMessage;

  DeepLinkState copyWith({
    DeepLinkStatus? status,
    Uri? lastUri,
    String? errorMessage,
  }) {
    return DeepLinkState(
      status: status ?? this.status,
      lastUri: lastUri ?? this.lastUri,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, lastUri, errorMessage];
}
