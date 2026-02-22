// @tier: community
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:seafoundry_app/services/directory_search_service.dart';
import 'package:seafoundry_app/theme/spacing.dart';

class ChannelInviteSearchSheet extends StatefulWidget {
  const ChannelInviteSearchSheet({
    super.key,
    required this.selectedMemberIds,
    required this.onMembersAdded,
  });

  final Set<String> selectedMemberIds;
  final ValueChanged<List<DirectoryUserResult>> onMembersAdded;

  static Future<void> show(
    BuildContext context, {
    required Set<String> selectedMemberIds,
    required ValueChanged<List<DirectoryUserResult>> onMembersAdded,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChannelInviteSearchSheet(
        selectedMemberIds: selectedMemberIds,
        onMembersAdded: onMembersAdded,
      ),
    );
  }

  @override
  State<ChannelInviteSearchSheet> createState() =>
      _ChannelInviteSearchSheetState();
}

class _ChannelInviteSearchSheetState extends State<ChannelInviteSearchSheet> {
  final _searchController = TextEditingController();
  final _service = DirectorySearchService();
  Timer? _debounce;
  bool _isLoading = false;
  String? _error;
  DirectorySearchResult _results = const DirectorySearchResult();
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.from(widget.selectedMemberIds);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = const DirectorySearchResult();
        _error = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      try {
        final results = await _service.search(trimmed);
        if (!mounted) return;
        setState(() {
          _results = results;
          _isLoading = false;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = 'Unable to search directory. Try again.';
        });
      }
    });
  }

  void _addMembers(List<DirectoryUserResult> members) {
    if (members.isEmpty) return;
    final newIds = members.map((m) => m.id).toSet();
    setState(() {
      _selectedIds.addAll(newIds);
    });
    widget.onMembersAdded(members);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: Spacing.lg,
          right: Spacing.lg,
          top: Spacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(theme),
            SizedBox(height: Spacing.md),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                labelText: 'Search by email or organization',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (_searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null),
              ),
            ),
            if (_error != null)
              Padding(
                padding: EdgeInsets.only(top: Spacing.sm),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            SizedBox(height: Spacing.md),
            Flexible(
              child: _buildResults(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Invite Organization',
          style: theme.textTheme.titleLarge,
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildResults(ThemeData theme) {
    if (_searchController.text.trim().isEmpty) {
      return Center(
        child: Text(
          'Search for an email or organization to invite.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final users = _results.users;
    final orgs = _results.organizations;

    if (users.isEmpty && orgs.isEmpty && !_isLoading) {
      return Center(
        child: Text(
          'No matches found.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      children: [
        if (users.isNotEmpty) ...[
          _SectionLabel(label: 'People'),
          ...users.map((user) => _buildUserTile(user, theme)),
          SizedBox(height: Spacing.md),
        ],
        if (orgs.isNotEmpty) ...[
          _SectionLabel(label: 'Organizations'),
          ...orgs.map((org) => _buildOrgTile(org, theme)),
        ],
      ],
    );
  }

  Widget _buildUserTile(DirectoryUserResult user, ThemeData theme) {
    final isSelected = _selectedIds.contains(user.id);
    final subtitle = user.organizationName != null && user.organizationName!.isNotEmpty
        ? '${user.email} • ${user.organizationName}'
        : user.email;
    final canInviteOrg = user.organizationId != null && user.organizationId!.isNotEmpty;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
        ),
      ),
      title: Text(user.name.isNotEmpty ? user.name : user.email),
      subtitle: Text(subtitle),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
          : const Icon(Icons.add_circle_outline),
      onTap: isSelected
          ? null
          : () {
              if (!canInviteOrg) {
                setState(() => _error = 'This user is not linked to an organization.');
                return;
              }
              DirectoryOrganizationResult? org;
              for (final candidate in _results.organizations) {
                if (candidate.id == user.organizationId) {
                  org = candidate;
                  break;
                }
              }
              final members = org?.members ?? const <DirectoryUserResult>[];
              if (members.isEmpty) {
                setState(() => _error = 'No members found for ${user.organizationName ?? 'this organization'}.');
                return;
              }
              _addMembers(members);
            },
    );
  }

  Widget _buildOrgTile(DirectoryOrganizationResult org, ThemeData theme) {
    final memberCount = org.members.length;
    final isSelected =
        memberCount > 0 && _selectedIds.containsAll(org.members.map((m) => m.id));
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.business_outlined)),
      title: Text(org.name),
      subtitle: Text(org.domain.isNotEmpty ? org.domain : 'Organization'),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
          : TextButton(
              onPressed:
                  memberCount == 0 ? null : () => _addMembers(org.members),
              child: Text(memberCount == 0
                  ? 'No members'
                  : 'Invite org ($memberCount)'),
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: Spacing.xs, top: Spacing.sm),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
