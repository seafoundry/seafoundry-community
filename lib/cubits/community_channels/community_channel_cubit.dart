// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';

import '../base/cubit_stream_subscription_mixin.dart';
import '../../models/channels/channel.dart';
import '../../models/types/channel_type.dart';
import '../../models/types/channel_visibility.dart';
import '../../repositories/channels/community_channel_repository.dart';
import '../../services/logging_service.dart';
import 'community_channel_state.dart';

class CommunityChannelCubit extends Cubit<CommunityChannelState>
    with CubitStreamSubscriptionMixin {
  CommunityChannelCubit({
    required CommunityChannelRepository repository,
    LoggingService? logger,
  })  : _repository = repository,
        _logger = logger ?? LoggingService.instance,
        super(
          CommunityChannelState(
            channels: _buildDefaultChannels(),
            selectedChannelId: _defaultChannelNames.first,
            isLoading: true,
          ),
        );

  final CommunityChannelRepository _repository;
  final LoggingService _logger;

  static const List<String> _defaultChannelNames = [
    'general',
    'restoration',
    'research',
    'equipment',
    'opportunities',
    'issues',
  ];

  void loadChannels() {
    emit(state.copyWith(isLoading: true));
    listenWithKey<List<Channel>>(
      'communityChannels',
      _repository.streamChannels(),
      onData: _handleChannelsUpdated,
      onError: _handleChannelsError,
    );
  }

  void selectChannel(String channelId) {
    if (channelId.isEmpty) return;
    emit(state.copyWith(selectedChannelId: channelId));
  }

  void togglePublicExpanded() {
    emit(state.copyWith(publicExpanded: !state.publicExpanded));
  }

  void togglePrivateExpanded() {
    emit(state.copyWith(privateExpanded: !state.privateExpanded));
  }

  void _handleChannelsUpdated(List<Channel> channels) {
    final merged = _mergeChannels(channels);
    final resolvedSelection =
        _resolveSelection(state.selectedChannelId, merged);

    emit(state.copyWith(
      channels: merged,
      selectedChannelId: resolvedSelection,
      isLoading: false,
      errorMessage: null,
    ));
  }

  void _handleChannelsError(Object error, StackTrace stackTrace) {
    _logger.error('Error streaming community channels', error, stackTrace);
    emit(state.copyWith(
      isLoading: false,
      errorMessage: 'Unable to load channels. Please try again.',
    ));
  }

  static List<Channel> _buildDefaultChannels() {
    return _defaultChannelNames
        .map((name) => Channel(
              id: name,
              name: name,
              channelType: ChannelType.community,
              visibility: ChannelVisibility.public_,
            ))
        .toList();
  }

  List<Channel> _mergeChannels(List<Channel> channels) {
    final fetchedByName = <String, Channel>{
      for (final channel in channels) channel.name: channel,
    };

    final merged = <Channel>[];
    for (final name in _defaultChannelNames) {
      merged.add(fetchedByName.remove(name) ?? _defaultChannel(name));
    }

    final extras = fetchedByName.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    merged.addAll(extras);

    return merged;
  }

  Channel _defaultChannel(String name) {
    return Channel(
      id: name,
      name: name,
      channelType: ChannelType.community,
      visibility: ChannelVisibility.public_,
    );
  }

  String? _resolveSelection(
    String? selectedChannelId,
    List<Channel> channels,
  ) {
    if (channels.isEmpty) return null;
    if (selectedChannelId != null) {
      final directMatch = channels.where((c) => c.id == selectedChannelId);
      if (directMatch.isNotEmpty) {
        return directMatch.first.id;
      }
      final nameMatch = channels.where((c) => c.name == selectedChannelId);
      if (nameMatch.isNotEmpty) {
        return nameMatch.first.id;
      }
    }
    return channels.first.id;
  }
}
