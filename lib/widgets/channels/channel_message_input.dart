// @tier: community

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seafoundry_app/models/channels/channel_message.dart';
import 'package:seafoundry_app/theme/app_colors.dart';

/// Text input for composing channel messages
class ChannelMessageInput extends StatefulWidget {
  const ChannelMessageInput({
    required this.onSend,
    this.onCancelReply,
    this.replyToMessage,
    this.isSending = false,
    this.enabled = true,
    this.placeholder = 'Type a message...',
    super.key,
  });

  final void Function(String content) onSend;
  final VoidCallback? onCancelReply;
  final ChannelMessage? replyToMessage;
  final bool isSending;
  final bool enabled;
  final String placeholder;

  @override
  State<ChannelMessageInput> createState() => _ChannelMessageInputState();
}

class _ChannelMessageInputState extends State<ChannelMessageInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _handleSend() {
    final content = _controller.text.trim();
    if (content.isEmpty || !widget.enabled || widget.isSending) return;

    widget.onSend(content);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.divider),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.withOpacity(AppColors.shadow, 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reply preview
            if (widget.replyToMessage != null) _buildReplyPreview(context),

            // Input row
            _buildInputRow(context),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    final replyMessage = widget.replyToMessage!;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          left: BorderSide(
            color: AppColors.primary,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${replyMessage.senderName ?? "Unknown"}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  replyMessage.content,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: widget.onCancelReply,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            padding: EdgeInsets.zero,
            color: AppColors.textHint,
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text input
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                maxHeight: 120,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    // Use Focus widget with onKeyEvent to handle Enter key
                    // while keeping TextField's focus management intact
                    child: Focus(
                      onKeyEvent: (node, event) {
                        // Send on Enter (without Shift for newline support)
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.enter &&
                            !HardwareKeyboard.instance.isShiftPressed) {
                          _handleSend();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        enabled: widget.enabled,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: widget.placeholder,
                          hintStyle: TextStyle(
                            color: AppColors.textHint,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: _buildSendButton(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton(BuildContext context) {
    final canSend = _hasText && widget.enabled && !widget.isSending;

    return Material(
      color: canSend ? AppColors.primary : AppColors.divider,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: canSend ? _handleSend : null,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(10),
          child: widget.isSending
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      canSend ? Colors.white : AppColors.textHint,
                    ),
                  ),
                )
              : Icon(
                  Icons.send,
                  size: 24,
                  color: canSend ? Colors.white : AppColors.textHint,
                ),
        ),
      ),
    );
  }
}
