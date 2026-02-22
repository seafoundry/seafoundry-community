// @tier: community

import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/channels/channel.dart';
import 'package:seafoundry_app/models/types/channel_type.dart';
import 'package:seafoundry_app/theme/app_colors.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Single channel tile for the sidebar
class ChannelTile extends StatelessWidget {
  const ChannelTile({
    required this.channel,
    required this.onTap,
    this.isSelected = false,
    this.isStarred = false,
    this.unreadCount = 0,
    this.isCollapsed = false,
    this.onStar,
    super.key,
  });

  final Channel channel;
  final VoidCallback onTap;
  final bool isSelected;
  final bool isStarred;
  final int unreadCount;
  final bool isCollapsed;
  final VoidCallback? onStar;

  @override
  Widget build(BuildContext context) {
    if (isCollapsed) {
      return _buildCollapsedTile(context);
    }
    return _buildExpandedTile(context);
  }

  Widget _buildCollapsedTile(BuildContext context) {
    return Tooltip(
      message: _getChannelDisplayName(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          child: Stack(
            children: [
              Center(child: _buildIcon(context)),
              if (unreadCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: _buildUnreadBadge(context, compact: true),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedTile(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Channel icon
            _buildIcon(context),
            const SizedBox(width: 8),

            // Channel name and preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Star indicator
                      if (isStarred)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.star,
                            size: 12,
                            color: AppColors.warning,
                          ),
                        ),

                      // Channel name
                      Expanded(
                        child: Text(
                          _getChannelDisplayName(),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Timestamp
                      if (channel.lastMessageAt != null)
                        Text(
                          timeago.format(
                            channel.lastMessageAtDateTime!,
                            locale: 'en_short',
                          ),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textHint,
                                fontSize: 10,
                              ),
                        ),
                    ],
                  ),

                  // Last message preview
                  if (channel.lastMessagePreview != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        channel.lastMessagePreview!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),

            // Unread badge
            if (unreadCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _buildUnreadBadge(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    // For DM channels, show avatar with initials
    if (channel.channelType == ChannelType.directMessage) {
      return CircleAvatar(
        radius: 16,
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
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          Icons.tag,
          size: 18,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildUnreadBadge(BuildContext context, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6,
        vertical: compact ? 2 : 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: BoxConstraints(
        minWidth: compact ? 16 : 20,
      ),
      child: Text(
        unreadCount > 99 ? '99+' : unreadCount.toString(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.bold,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _getChannelDisplayName() {
    if (channel.channelType == ChannelType.directMessage) {
      // For DMs, show participant names
      if (channel.name.isNotEmpty) {
        return channel.name;
      }
      // Fallback to "Direct Message"
      return 'Direct Message';
    }

    return channel.name;
  }

  String _getDMInitials() {
    final name = _getChannelDisplayName();
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
