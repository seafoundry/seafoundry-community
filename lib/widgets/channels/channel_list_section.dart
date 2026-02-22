// @tier: community

import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/channels/channel.dart';
import 'package:seafoundry_app/theme/app_colors.dart';
import 'package:seafoundry_app/widgets/channels/channel_tile.dart';

/// Collapsible section of channels in the sidebar
class ChannelListSection extends StatefulWidget {
  const ChannelListSection({
    required this.title,
    required this.channels,
    required this.onChannelTap,
    this.icon,
    this.selectedChannelId,
    this.starredChannelIds = const {},
    this.isCollapsed = false,
    this.initiallyExpanded = true,
    this.onAddChannel,
    super.key,
  });

  final String title;
  final List<Channel> channels;
  final Function(String channelId) onChannelTap;
  final IconData? icon;
  final String? selectedChannelId;
  final Set<String> starredChannelIds;
  final bool isCollapsed;
  final bool initiallyExpanded;
  final VoidCallback? onAddChannel;

  @override
  State<ChannelListSection> createState() => _ChannelListSectionState();
}

class _ChannelListSectionState extends State<ChannelListSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.channels.isEmpty && widget.onAddChannel == null) {
      return const SizedBox.shrink();
    }

    if (widget.isCollapsed) {
      return _buildCollapsedSection(context);
    }

    return _buildExpandedSection(context);
  }

  Widget _buildCollapsedSection(BuildContext context) {
    // In collapsed mode, just show the first few channel icons
    return Column(
      children: [
        // Section divider with icon
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Tooltip(
            message: widget.title,
            child: Icon(
              widget.icon ?? Icons.tag,
              size: 16,
              color: AppColors.textHint,
            ),
          ),
        ),
        // Show up to 3 channel icons
        ...widget.channels.take(3).map((channel) => ChannelTile(
              channel: channel,
              onTap: () => widget.onChannelTap(channel.id),
              isSelected: channel.id == widget.selectedChannelId,
              isCollapsed: true,
            )),
        if (widget.channels.length > 3)
          Tooltip(
            message: '+${widget.channels.length - 3} more',
            child: Container(
              width: 40,
              height: 24,
              margin: const EdgeInsets.symmetric(vertical: 2),
              child: Center(
                child: Text(
                  '+${widget.channels.length - 3}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textHint,
                        fontSize: 10,
                      ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExpandedSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    widget.title.toUpperCase(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                  ),
                ),
                // Add channel button
                if (widget.onAddChannel != null)
                  IconButton(
                    icon: Icon(
                      Icons.add,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: widget.onAddChannel,
                    tooltip: 'New ${widget.title.toLowerCase().replaceAll('s', '')}',
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
        ),

        // Channel list
        if (_isExpanded)
          ...widget.channels.map((channel) => ChannelTile(
                channel: channel,
                onTap: () => widget.onChannelTap(channel.id),
                isSelected: channel.id == widget.selectedChannelId,
                isStarred: widget.starredChannelIds.contains(channel.id),
              )),

        // Empty state
        if (_isExpanded && widget.channels.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'No channels yet',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textHint,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
      ],
    );
  }
}
