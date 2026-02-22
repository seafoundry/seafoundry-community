// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubits/community_channels/community_channels.dart';
import '../../models/channels/channel.dart';
import '../../models/types/channel_visibility.dart';

class CommunitySidebar extends StatelessWidget {
  final List<Channel> channels;
  final String? selectedChannelId;
  final ValueChanged<Channel> onChannelSelected;
  final VoidCallback onCreateChannel;
  final bool isEmbedded;

  const CommunitySidebar({
    super.key,
    required this.channels,
    required this.selectedChannelId,
    required this.onChannelSelected,
    required this.onCreateChannel,
    this.isEmbedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final publicChannels = channels
        .where((c) => c.visibility == ChannelVisibility.public_)
        .toList();
    final privateChannels = channels
        .where((c) => c.visibility != ChannelVisibility.public_)
        .toList();

    return BlocBuilder<CommunityChannelCubit, CommunityChannelState>(
      buildWhen: (prev, curr) =>
          prev.publicExpanded != curr.publicExpanded ||
          prev.privateExpanded != curr.privateExpanded,
      builder: (context, state) {
        final sectionChildren = [
          _SectionHeader(title: 'CHANNELS'),
          _ChannelSection(
            title: 'Public Channels',
            channels: publicChannels,
            isExpanded: state.publicExpanded,
            onToggle: context.read<CommunityChannelCubit>().togglePublicExpanded,
            selectedChannelId: selectedChannelId,
            onChannelSelected: onChannelSelected,
          ),
          _ChannelSection(
            title: 'Private Channels',
            channels: privateChannels,
            isExpanded: state.privateExpanded,
            onToggle:
                context.read<CommunityChannelCubit>().togglePrivateExpanded,
            selectedChannelId: selectedChannelId,
            onChannelSelected: onChannelSelected,
            emptyLabel: 'No private channels yet',
          ),
          const SizedBox(height: 16),
          _CreateChannelButton(onPressed: onCreateChannel),
        ];

        return Container(
          width: 250,
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainer
                : theme.colorScheme.surface,
            border: Border(
              right: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.hub, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'SeaFoundry',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (isEmbedded)
                ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  primary: false,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: sectionChildren,
                )
              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: sectionChildren,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Private extracted widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.hintColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ChannelSection extends StatelessWidget {
  const _ChannelSection({
    required this.title,
    required this.channels,
    required this.isExpanded,
    required this.onToggle,
    required this.selectedChannelId,
    required this.onChannelSelected,
    this.emptyLabel,
  });

  final String title;
  final List<Channel> channels;
  final bool isExpanded;
  final VoidCallback onToggle;
  final String? selectedChannelId;
  final ValueChanged<Channel> onChannelSelected;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 18,
                  color: theme.hintColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                if (channels.isNotEmpty)
                  Text(
                    '${channels.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          ...channels.map(
            (channel) => _ChannelTile(
              channel: channel,
              isSelected: channel.id == selectedChannelId,
              onTap: () => onChannelSelected(channel),
            ),
          ),
        if (isExpanded && channels.isEmpty && emptyLabel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 16, 8),
            child: Text(
              emptyLabel!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.isSelected,
    required this.onTap,
  });

  final Channel channel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ListTile(
        leading: _buildLeading(theme),
        title: Text(
          channel.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? theme.colorScheme.primary : null,
          ),
        ),
        selected: isSelected,
        dense: true,
        selectedTileColor:
            theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        onTap: onTap,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(ThemeData theme) {
    final emoji = channel.iconEmoji;
    if (emoji != null && emoji.isNotEmpty && emoji != '#') {
      return SizedBox(
        width: 24,
        height: 24,
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 16)),
        ),
      );
    }
    return Icon(
      _iconForChannelName(channel.name),
      color: isSelected ? theme.colorScheme.primary : null,
      size: 20,
    );
  }

  static IconData _iconForChannelName(String name) {
    switch (name) {
      case 'general':
        return Icons.chat_bubble_outline;
      case 'restoration':
        return Icons.volunteer_activism_outlined;
      case 'research':
        return Icons.science_outlined;
      case 'equipment':
        return Icons.build_outlined;
      case 'opportunities':
        return Icons.work_outline;
      default:
        return Icons.tag;
    }
  }
}

class _CreateChannelButton extends StatelessWidget {
  const _CreateChannelButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: const Icon(Icons.add),
        label: const Text('New Channel'),
      ),
    );
  }
}
