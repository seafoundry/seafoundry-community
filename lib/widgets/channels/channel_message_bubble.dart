// @tier: community

import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/channels/channel_message.dart';
import 'package:seafoundry_app/theme/app_colors.dart';
import 'package:timeago/timeago.dart' as timeago;

/// A single message bubble in the channel message view
class ChannelMessageBubble extends StatelessWidget {
  const ChannelMessageBubble({
    required this.message,
    required this.isOwnMessage,
    this.showSenderName = true,
    this.onReply,
    this.onReaction,
    this.onPin,
    this.onEdit,
    this.onDelete,
    this.currentUserId,
    super.key,
  });

  final ChannelMessage message;
  final bool isOwnMessage;
  final bool showSenderName;
  final VoidCallback? onReply;
  final void Function(String emoji)? onReaction;
  final VoidCallback? onPin;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return _buildDeletedMessage(context);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment:
            isOwnMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Reply preview if this is a reply
          if (message.isReply && message.replyToPreview != null)
            _buildReplyPreview(context),

          // Pinned indicator
          if (message.isPinned) _buildPinnedIndicator(context),

          // Main message row
          Row(
            mainAxisAlignment:
                isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isOwnMessage) ...[
                _buildAvatar(context),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: GestureDetector(
                  onLongPress: () => _showMessageActions(context),
                  child: _buildMessageContent(context),
                ),
              ),
              if (isOwnMessage) ...[
                const SizedBox(width: 8),
                _buildAvatar(context),
              ],
            ],
          ),

          // Reactions row
          if (message.hasReactions) _buildReactions(context),
        ],
      ),
    );
  }

  Widget _buildDeletedMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          'This message was deleted',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textHint,
                fontStyle: FontStyle.italic,
              ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: isOwnMessage ? 48 : 48,
        right: isOwnMessage ? 48 : 48,
        bottom: 4,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: AppColors.primary,
            width: 3,
          ),
        ),
      ),
      child: Text(
        message.replyToPreview!,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildPinnedIndicator(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: isOwnMessage ? 48 : 48,
        right: isOwnMessage ? 48 : 48,
        bottom: 4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.push_pin,
            size: 12,
            color: AppColors.warning,
          ),
          const SizedBox(width: 4),
          Text(
            'Pinned',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final initials = _getInitials();
    return CircleAvatar(
      radius: 16,
      backgroundColor: isOwnMessage ? AppColors.primary : AppColors.primaryLight,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isOwnMessage ? Colors.white : AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isOwnMessage ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isOwnMessage ? 16 : 4),
          bottomRight: Radius.circular(isOwnMessage ? 4 : 16),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.withOpacity(AppColors.shadow, 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender name
          if (showSenderName && !isOwnMessage)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                message.senderName ?? 'Unknown',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),

          // Message content
          Text(
            message.content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isOwnMessage ? Colors.white : AppColors.textPrimary,
                ),
          ),

          // Timestamp and edited indicator
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeago.format(message.createdAtDateTime),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isOwnMessage
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.textHint,
                      fontSize: 10,
                    ),
              ),
              if (message.isEdited) ...[
                Text(
                  ' (edited)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isOwnMessage
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppColors.textHint,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReactions(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: isOwnMessage ? 48 : 48,
        right: isOwnMessage ? 48 : 48,
        top: 4,
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: message.reactions.entries.map((entry) {
          final emoji = entry.key;
          final users = entry.value;
          final hasReacted = currentUserId != null && users.contains(currentUserId);

          return InkWell(
            onTap: onReaction != null ? () => onReaction!(emoji) : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: hasReacted
                    ? AppColors.primaryLight
                    : AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasReacted ? AppColors.primary : AppColors.divider,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    users.length.toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: hasReacted
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight:
                              hasReacted ? FontWeight.bold : FontWeight.normal,
                        ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showMessageActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick reactions row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      onReaction?.call(emoji);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),

            // Action buttons
            if (onReply != null)
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  onReply?.call();
                },
              ),
            if (onPin != null)
              ListTile(
                leading: Icon(message.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
                title: Text(message.isPinned ? 'Unpin' : 'Pin'),
                onTap: () {
                  Navigator.pop(context);
                  onPin?.call();
                },
              ),
            if (isOwnMessage && onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  onEdit?.call();
                },
              ),
            if (isOwnMessage && onDelete != null)
              ListTile(
                leading: Icon(Icons.delete, color: AppColors.error),
                title: Text('Delete', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  onDelete?.call();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _getInitials() {
    final name = message.senderName ?? 'Unknown';
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
