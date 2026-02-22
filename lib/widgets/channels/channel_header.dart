// @tier: community

import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/channels/channel.dart';
import 'package:seafoundry_app/models/types/channel_type.dart';
import 'package:seafoundry_app/theme/app_colors.dart';

/// Header bar for the selected channel
class ChannelHeader extends StatelessWidget {
  const ChannelHeader({
    required this.channel,
    this.isStarred = false,
    this.isMuted = false,
    this.onStar,
    this.onMute,
    this.onSettings,
    this.onMembers,
    this.onPinned,
    super.key,
  });

  final Channel channel;
  final bool isStarred;
  final bool isMuted;
  final VoidCallback? onStar;
  final VoidCallback? onMute;
  final VoidCallback? onSettings;
  final VoidCallback? onMembers;
  final VoidCallback? onPinned;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.withOpacity(AppColors.shadow, 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),

          // Channel icon/emoji
          _buildIcon(context),
          const SizedBox(width: 12),

          // Channel name and description
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _getChannelDisplayName(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (isMuted)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.notifications_off,
                          size: 16,
                          color: AppColors.textHint,
                        ),
                      ),
                  ],
                ),
                if (channel.description != null && channel.description!.isNotEmpty)
                  Text(
                    channel.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Action buttons
          if (onPinned != null)
            IconButton(
              icon: const Icon(Icons.push_pin_outlined),
              tooltip: 'View pinned messages',
              onPressed: onPinned,
              color: AppColors.textSecondary,
            ),

          if (onMembers != null)
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.people_outline),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        channel.memberCount.toString(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
              tooltip: '${channel.memberCount} members',
              onPressed: onMembers,
              color: AppColors.textSecondary,
            ),

          if (onStar != null)
            IconButton(
              icon: Icon(
                isStarred ? Icons.star : Icons.star_border,
              ),
              tooltip: isStarred ? 'Unstar channel' : 'Star channel',
              onPressed: onStar,
              color: isStarred ? AppColors.warning : AppColors.textSecondary,
            ),

          if (onMute != null)
            IconButton(
              icon: Icon(
                isMuted ? Icons.notifications_off : Icons.notifications_outlined,
              ),
              tooltip: isMuted ? 'Unmute channel' : 'Mute channel',
              onPressed: onMute,
              color: AppColors.textSecondary,
            ),

          if (onSettings != null)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Channel settings',
              onPressed: onSettings,
              color: AppColors.textSecondary,
            ),

          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    // For DM channels, show avatar
    if (channel.channelType == ChannelType.directMessage) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.primaryLight,
        child: Text(
          _getDMInitials(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      );
    }

    // For regular channels, show hash or emoji
    final emoji = channel.iconEmoji;
    if (emoji != null && emoji.isNotEmpty && emoji != '#') {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      );
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          Icons.tag,
          size: 20,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  String _getChannelDisplayName() {
    if (channel.channelType == ChannelType.directMessage) {
      if (channel.name.isNotEmpty) {
        return channel.name;
      }
      return 'Direct Message';
    }

    return '#${channel.name}';
  }

  String _getDMInitials() {
    final name = channel.name.isNotEmpty ? channel.name : 'DM';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (name.length >= 2) {
      return name.substring(0, 2).toUpperCase();
    }
    return name.toUpperCase();
  }
}
