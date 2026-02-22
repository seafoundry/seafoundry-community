// @tier: community

import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/user.dart';
import 'package:seafoundry_app/widgets/dialogs/mission_edit_dialog_crew_sheet.dart';
import 'package:seafoundry_app/widgets/dialogs/channel_invite_search_sheet.dart';

import '../../models/channels/channel.dart';
import '../../models/types/channel_type.dart';
import '../../models/types/channel_visibility.dart';
import '../../repositories/channels/community_channel_repository.dart';
import '../../repositories/channels/organization_channel_repository.dart';
import 'components/dialog_message_box.dart';
import 'components/safe_dialog_mixin.dart';
import 'components/dialog_scroll_view.dart';

/// Mode for channel management operations
enum ChannelManagementMode {
  /// Create a new channel
  create,

  /// Edit an existing channel
  edit,

  /// Archive/delete a channel
  archive,
}

/// Result describing channel management dialog outcomes
class ChannelManagementResult {
  const ChannelManagementResult({
    this.createdChannel,
    this.updatedChannel,
    this.archivedChannelId,
  });

  /// The channel that was created
  final Channel? createdChannel;

  /// The channel that was updated
  final Channel? updatedChannel;

  /// ID of channel that was archived
  final String? archivedChannelId;

  bool get hasChanges =>
      createdChannel != null || updatedChannel != null || archivedChannelId != null;
}

/// Unified dialog for channel management operations
///
/// This dialog consolidates channel management operations (create, edit, archive)
/// into a single entry point following the ManagementDialog pattern.
///
/// Usage:
/// ```dart
/// // Create new community channel
/// final result = await ChannelManagementDialog.show(
///   context,
///   mode: ChannelManagementMode.create,
///   channelType: ChannelType.community,
///   communityChannelRepository: communityRepo,
/// );
///
/// // Edit existing channel
/// final result = await ChannelManagementDialog.show(
///   context,
///   mode: ChannelManagementMode.edit,
///   channel: existingChannel,
///   communityChannelRepository: communityRepo,
/// );
/// ```
class ChannelManagementDialog {
  ChannelManagementDialog._();

  /// Show the channel management dialog
  ///
  /// [mode] determines the operation (create, edit, or archive)
  /// [channelType] is required for create mode to specify channel type
  /// [channel] is required for edit and archive modes
  /// [communityChannelRepository] required for community channel operations
  /// [organizationChannelRepository] optional for organization channel operations
  /// [onUpdated] optional callback when channel is successfully updated
  ///
  /// Returns a [ChannelManagementResult] describing updates or archival.
  /// Null when the dialog is dismissed without changes.
  static Future<ChannelManagementResult?> show(
    BuildContext context, {
    required ChannelManagementMode mode,
    ChannelType channelType = ChannelType.community,
    Channel? channel,
    CommunityChannelRepository? communityChannelRepository,
    OrganizationChannelRepository? organizationChannelRepository,
    List<User>? organizationMembers,
    VoidCallback? onUpdated,
  }) async {
    if (mode != ChannelManagementMode.create && channel == null) {
      throw ArgumentError('channel is required for edit and archive modes');
    }

    if (mode == ChannelManagementMode.create) {
      if (channelType == ChannelType.community && communityChannelRepository == null) {
        throw ArgumentError('communityChannelRepository required for community channels');
      }
      if (channelType == ChannelType.organization && organizationChannelRepository == null) {
        throw ArgumentError('organizationChannelRepository required for organization channels');
      }
    }

    switch (mode) {
      case ChannelManagementMode.create:
        return showDialog<ChannelManagementResult>(
          context: context,
          useRootNavigator: false,
          builder: (dialogContext) {
            return _ChannelCreateEditDialog(
              channelType: channelType,
              communityChannelRepository: communityChannelRepository,
              organizationChannelRepository: organizationChannelRepository,
              organizationMembers: organizationMembers,
              isEdit: false,
              onUpdated: onUpdated,
            );
          },
        );

      case ChannelManagementMode.edit:
        return showDialog<ChannelManagementResult>(
          context: context,
          useRootNavigator: false,
          builder: (dialogContext) {
            return _ChannelCreateEditDialog(
              channel: channel,
              channelType: channel!.channelType,
              communityChannelRepository: communityChannelRepository,
              organizationChannelRepository: organizationChannelRepository,
              organizationMembers: organizationMembers,
              isEdit: true,
              onUpdated: onUpdated,
            );
          },
        );

      case ChannelManagementMode.archive:
        return showDialog<ChannelManagementResult>(
          context: context,
          useRootNavigator: false,
          builder: (dialogContext) {
            return _ChannelArchiveDialog(
              channel: channel!,
              communityChannelRepository: communityChannelRepository,
              organizationChannelRepository: organizationChannelRepository,
              onUpdated: onUpdated,
            );
          },
        );
    }
  }
}

/// Dialog for creating or editing a channel
class _ChannelCreateEditDialog extends StatefulWidget {
  final Channel? channel;
  final ChannelType channelType;
  final CommunityChannelRepository? communityChannelRepository;
  final OrganizationChannelRepository? organizationChannelRepository;
  final List<User>? organizationMembers;
  final bool isEdit;
  final VoidCallback? onUpdated;

  const _ChannelCreateEditDialog({
    this.channel,
    required this.channelType,
    this.communityChannelRepository,
    this.organizationChannelRepository,
    this.organizationMembers,
    required this.isEdit,
    this.onUpdated,
  });

  @override
  State<_ChannelCreateEditDialog> createState() => _ChannelCreateEditDialogState();
}

class _ChannelCreateEditDialogState extends State<_ChannelCreateEditDialog>
    with SafeDialogMixin<_ChannelCreateEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late ChannelVisibility _visibility;
  late List<User> _availableMembers;
  List<String> _selectedMemberIds = [];
  final Map<String, String> _memberLabelOverrides = {};
  String? _selectedEmoji;
  bool _isLoading = false;
  String? _errorMessage;

  // Common channel emoji options
  static const List<String> _emojiOptions = [
    '#', // Default hash
    '💬', // General chat
    '📢', // Announcements
    '🔬', // Research
    '🌊', // Ocean/coral
    '📋', // Tasks
    '❓', // Questions
    '🎉', // Social
    '🛠️', // Tools/tech
    '📚', // Learning
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.channel?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.channel?.description ?? '');
    _visibility = widget.channel?.visibility ?? ChannelVisibility.inviteOnly;
    _selectedEmoji = widget.channel?.iconEmoji ?? '#';
    _availableMembers = widget.organizationMembers ?? [];
    _selectedMemberIds = widget.channel?.memberIds ?? [];
    if (!widget.isEdit) {
      _selectedMemberIds = [];
      _visibility = ChannelVisibility.inviteOnly;
    }
    if (widget.channelType == ChannelType.organization) {
      _visibility = ChannelVisibility.inviteOnly;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Channel name is required');
      return;
    }

    if (_visibility == ChannelVisibility.inviteOnly &&
        _canSelectMembers &&
        _selectedMemberIds.isEmpty) {
      setState(() => _errorMessage = 'Select at least one member for a private channel');
      return;
    }

    if (!_allowPublicVisibility && _visibility == ChannelVisibility.public_) {
      setState(() => _errorMessage = 'Public channels are managed by SeaFoundry.');
      return;
    }

    // Validate name format (lowercase, no spaces)
    final validName = name.toLowerCase().replaceAll(' ', '-');
    if (validName != name) {
      setState(() => _errorMessage = 'Channel name must be lowercase with no spaces (use dashes)');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Channel? result;

      if (widget.isEdit) {
        // Update existing channel
        if (widget.channelType == ChannelType.organization &&
            widget.organizationChannelRepository != null) {
          await widget.organizationChannelRepository!.updateChannel(
            channelId: widget.channel!.id,
            name: name,
            description: description.isEmpty ? null : description,
            isPublic: _visibility == ChannelVisibility.public_,
          );
          result = widget.channel!.copyWith(
            name: name,
            description: description.isEmpty ? null : description,
            visibility: _visibility,
          );
        } else if (widget.communityChannelRepository != null) {
          await widget.communityChannelRepository!.updateChannel(
            channelId: widget.channel!.id,
            name: name,
            description: description.isEmpty ? null : description,
            visibility: _visibility,
          );
          result = widget.channel!.copyWith(
            name: name,
            description: description.isEmpty ? null : description,
            visibility: _visibility,
          );
        }

        if (widget.channelType == ChannelType.community &&
            widget.communityChannelRepository != null &&
            result != null &&
            _visibility == ChannelVisibility.inviteOnly) {
          await _syncCommunityMembers(
            widget.communityChannelRepository!,
            result,
          );
        }

        if (mounted) {
          widget.onUpdated?.call();
          popDialog(ChannelManagementResult(updatedChannel: result));
        }
      } else {
        // Create new channel
        if (widget.channelType == ChannelType.organization &&
            widget.organizationChannelRepository != null) {
          result = await widget.organizationChannelRepository!.createChannel(
            name: name,
            description: description.isEmpty ? null : description,
            isPublic: false,
            iconEmoji: _selectedEmoji != '#' ? _selectedEmoji : null,
            initialMemberIds: _visibility == ChannelVisibility.inviteOnly &&
                    _selectedMemberIds.isNotEmpty
                ? _selectedMemberIds
                : null,
          );
        } else if (widget.communityChannelRepository != null) {
          result = await widget.communityChannelRepository!.createChannel(
            name: name,
            description: description.isEmpty ? null : description,
            iconEmoji: _selectedEmoji,
            visibility: _visibility,
            initialMemberIds: _visibility == ChannelVisibility.inviteOnly &&
                    _selectedMemberIds.isNotEmpty
                ? _selectedMemberIds
                : null,
          );
        }

        if (mounted) {
          widget.onUpdated?.call();
          popDialog(ChannelManagementResult(createdChannel: result));
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = error.toString();
        });
      }
    }
  }

  bool get _canSelectMembers {
    if (widget.channelType == ChannelType.community) {
      return true;
    }
    return widget.channelType == ChannelType.organization &&
        !widget.isEdit &&
        _availableMembers.isNotEmpty;
  }

  bool get _allowPublicVisibility {
    return widget.channelType == ChannelType.community &&
        widget.isEdit &&
        widget.channel?.visibility == ChannelVisibility.public_;
  }

  List<User> get _selectedMembers {
    if (_selectedMemberIds.isEmpty) return const [];
    return _availableMembers
        .where((member) => _selectedMemberIds.contains(member.id))
        .toList();
  }

  List<String> get _selectedMemberLabels {
    if (_selectedMemberIds.isEmpty) return const [];
    if (widget.channelType == ChannelType.organization) {
      return _selectedMembers.map((member) => member.name).toList();
    }
    return _selectedMemberIds
        .map((id) => _memberLabelOverrides[id] ?? id)
        .toList();
  }

  void _openMemberSelector() {
    if (widget.channelType == ChannelType.community) {
      ChannelInviteSearchSheet.show(
        context,
        selectedMemberIds: _selectedMemberIds.toSet(),
        onMembersAdded: (members) {
          if (!mounted) return;
          setState(() {
            for (final member in members) {
              _selectedMemberIds.add(member.id);
              _memberLabelOverrides[member.id] =
                  member.name.isNotEmpty ? member.name : member.email;
            }
          });
        },
      );
      return;
    }

    MissionCrewSelectorSheet.show(
      context,
      availableCrew: _availableMembers,
      selectedCrewIds: _selectedMemberIds,
      onSelectionChanged: (ids) {
        if (!mounted) return;
        setState(() => _selectedMemberIds = ids);
      },
    );
  }

  Future<void> _syncCommunityMembers(
    CommunityChannelRepository repository,
    Channel channel,
  ) async {
    final currentIds = channel.memberIds.toSet();
    final targetIds = _selectedMemberIds.toSet();
    final lockedIds = <String>{
      if (channel.createdById != null) channel.createdById!,
      ...channel.adminIds,
    };

    targetIds.addAll(lockedIds);

    final toAdd = targetIds.difference(currentIds).toList();
    final toRemove =
        currentIds.difference(targetIds).where((id) => !lockedIds.contains(id)).toList();

    if (toAdd.isNotEmpty) {
      await repository.addMembers(channelId: channel.id, memberIds: toAdd);
    }
    if (toRemove.isNotEmpty) {
      await repository.removeMembers(channelId: channel.id, memberIds: toRemove);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowPublicVisibility = _allowPublicVisibility;
    return AlertDialog(
      title: Text(widget.isEdit ? 'Edit Channel' : 'Create Channel'),
      content: DialogScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DialogMessageBox.error(_errorMessage!),
              ),

            // Channel emoji selector
            Text(
              'Icon',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojiOptions.map((emoji) {
                final isSelected = _selectedEmoji == emoji;
                return InkWell(
                  onTap: _isLoading ? null : () => setState(() => _selectedEmoji = emoji),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: emoji == '#'
                          ? Icon(
                              Icons.tag,
                              size: 20,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            )
                          : Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Channel name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Channel Name *',
                hintText: 'general-discussion',
                helperText: 'Lowercase, no spaces (use dashes)',
              ),
              enabled: !_isLoading,
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 16),

            // Channel description
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What is this channel about?',
              ),
              enabled: !_isLoading,
              maxLines: 2,
            ),

            const SizedBox(height: 16),

            // Visibility selector (for non-DM channels)
            if (widget.channelType != ChannelType.directMessage) ...[
              Text(
                'Visibility',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<ChannelVisibility>(
                segments: [
                  if (allowPublicVisibility)
                    const ButtonSegment(
                      value: ChannelVisibility.public_,
                      label: Text('Public'),
                      icon: Icon(Icons.public, size: 18),
                    ),
                  const ButtonSegment(
                    value: ChannelVisibility.inviteOnly,
                    label: Text('Invite Only'),
                    icon: Icon(Icons.lock_outline, size: 18),
                  ),
                ],
                selected: {_visibility},
                onSelectionChanged: _isLoading
                    ? null
                    : (selection) =>
                        setState(() => _visibility = selection.first),
              ),
              const SizedBox(height: 8),
              Text(
                _visibility == ChannelVisibility.public_
                    ? 'Anyone can find and join this channel'
                    : 'Only invited members can see this channel',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              if (!allowPublicVisibility)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Public channels are managed by SeaFoundry.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
            ],

            if (_visibility == ChannelVisibility.inviteOnly && _canSelectMembers) ...[
              const SizedBox(height: 16),
              Text(
                'Members',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _openMemberSelector,
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: Text(
                  _selectedMemberIds.isEmpty
                      ? 'Invite members'
                      : 'Edit members (${_selectedMemberIds.length})',
                ),
              ),
              if (_selectedMemberIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _selectedMemberLabels.length <= 3
                      ? _selectedMemberLabels.join(', ')
                      : '${_selectedMemberLabels.take(3).join(', ')} +${_selectedMemberLabels.length - 3} more',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => popDialog(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

/// Dialog for archiving a channel
class _ChannelArchiveDialog extends StatefulWidget {
  final Channel channel;
  final CommunityChannelRepository? communityChannelRepository;
  final OrganizationChannelRepository? organizationChannelRepository;
  final VoidCallback? onUpdated;

  const _ChannelArchiveDialog({
    required this.channel,
    this.communityChannelRepository,
    this.organizationChannelRepository,
    this.onUpdated,
  });

  @override
  State<_ChannelArchiveDialog> createState() => _ChannelArchiveDialogState();
}

class _ChannelArchiveDialogState extends State<_ChannelArchiveDialog>
    with SafeDialogMixin<_ChannelArchiveDialog> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _confirmArchive() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.channel.channelType == ChannelType.organization &&
          widget.organizationChannelRepository != null) {
        await widget.organizationChannelRepository!.archiveChannel(widget.channel.id);
      } else if (widget.communityChannelRepository != null) {
        await widget.communityChannelRepository!.archiveChannel(widget.channel.id);
      }

      if (mounted) {
        widget.onUpdated?.call();
        popDialog(ChannelManagementResult(archivedChannelId: widget.channel.id));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Archive Channel'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DialogMessageBox.error(_errorMessage!),
            ),
          Text('Are you sure you want to archive "#${widget.channel.name}"?'),
          const SizedBox(height: 8),
          Text(
            'This channel will be hidden from the channel list. '
            'Members can still find it in search.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => popDialog(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _confirmArchive,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Text('Archive'),
        ),
      ],
    );
  }
}