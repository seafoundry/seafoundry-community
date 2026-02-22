// @tier: community
import 'package:equatable/equatable.dart';

import '../../models/channels/channel.dart';

/// Sentinel value to distinguish between "not provided" and "explicitly null".
const _sentinel = Object();

class CommunityChannelState extends Equatable {
  const CommunityChannelState({
    this.channels = const [],
    this.selectedChannelId,
    this.isLoading = false,
    this.errorMessage,
    this.publicExpanded = true,
    this.privateExpanded = false,
  });

  final List<Channel> channels;
  final String? selectedChannelId;
  final bool isLoading;
  final String? errorMessage;
  final bool publicExpanded;
  final bool privateExpanded;

  CommunityChannelState copyWith({
    List<Channel>? channels,
    Object? selectedChannelId = _sentinel,
    bool? isLoading,
    Object? errorMessage = _sentinel,
    bool? publicExpanded,
    bool? privateExpanded,
  }) {
    return CommunityChannelState(
      channels: channels ?? this.channels,
      selectedChannelId: selectedChannelId == _sentinel
          ? this.selectedChannelId
          : selectedChannelId as String?,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      publicExpanded: publicExpanded ?? this.publicExpanded,
      privateExpanded: privateExpanded ?? this.privateExpanded,
    );
  }

  @override
  List<Object?> get props => [
        channels,
        selectedChannelId,
        isLoading,
        errorMessage,
        publicExpanded,
        privateExpanded,
      ];
}
