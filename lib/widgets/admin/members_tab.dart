// @tier: community
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/current_user/current_user.dart';
import 'package:seafoundry_app/cubits/manage_members/manage_members_cubit.dart';
import 'package:seafoundry_app/models/billing/seat_pricing_summary.dart';
import 'package:seafoundry_app/models/invitation.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/models/types/user_role.dart';
import 'package:seafoundry_app/models/user.dart';
import 'package:seafoundry_app/repositories/invitation_repository.dart';
import 'package:seafoundry_app/repositories/user_repository.dart';
import 'package:seafoundry_app/widgets/admin/change_role_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

/// Tab for managing organization members and invitations within the Workforce screen.
class MembersTab extends StatefulWidget {
  const MembersTab({super.key});

  @override
  State<MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<MembersTab> {
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  void _handleStateChange(BuildContext context, ManageMembersState state) {
    if (state is ManageMembersLoaded) {
      if (state.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.successMessage!),
            backgroundColor: Colors.green,
          ),
        );
        context.read<ManageMembersCubit>().clearMessages();
      }
      if (state.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
        context.read<ManageMembersCubit>().clearMessages();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Repositories should be provided by CommunityRepositoriesProvider at app level.
    // We validate all required providers are available before creating the cubit.

    // Validate current user state
    final currentUserState = context.read<CurrentUser>().state;
    if (currentUserState is! CurrentUserLoaded) {
      return _buildProviderError('User session not loaded. Please sign in again.');
    }

    // Validate required repositories with graceful error handling
    UserRepository? userRepository;
    InvitationRepository? invitationRepository;

    try {
      userRepository = context.read<UserRepository>();
    } catch (e) {
      return _buildProviderError('User repository not available. Please restart the app.');
    }

    try {
      invitationRepository = context.read<InvitationRepository>();
    } catch (e) {
      return _buildProviderError('Invitation repository not available. Please restart the app.');
    }

    final currentUserRole = UserRole.fromId(currentUserState.user.role);
    final canManageUsers = currentUserRole?.canManageUsers ?? false;

    return BlocProvider(
      create: (context) {
        return ManageMembersCubit(
          userRepository: userRepository!,
          invitationRepository: invitationRepository!,
          organizationId: currentUserState.organization.id,
          currentUserId: currentUserState.user.id,
          organizationTier: currentUserState.organization.tier,
        )
          ..loadData()
          ..startRealtimeUpdates();
      },
      child: BlocConsumer<ManageMembersCubit, ManageMembersState>(
        listener: _handleStateChange,
        builder: (context, state) => _buildContent(
          context,
          state,
          currentUserState.organization.tier,
          canManageUsers,
        ),
      ),
    );
  }

  Widget _buildProviderError(String message) {
    return Center(
      child: Padding(
        padding: UI.paddingLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ManageMembersState state,
    Tier tier,
    bool canManageUsers,
  ) {
    final seatSummary = state is ManageMembersLoaded
        ? SeatPricingSummary.fromRoster(
            tier: tier,
            members: state.members,
            invitations: state.pendingInvitations,
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header / Actions
        Padding(
          padding: UI.paddingMd,
          child: Row(
            children: [
              Expanded(
                child: UIText.bodyMedium(
                  'Manage the people in your organization and their roles.',
                ),
              ),
              ElevatedButton.icon(
                onPressed: state is ManageMembersLoaded && canManageUsers
                    ? () => _showInviteMemberDialog(
                          context,
                          state,
                          seatSummary,
                        )
                    : null,
                icon: const Icon(Icons.person_add),
                label: const Text('Invite Member'),
              ),
            ],
          ),
        ),
        if (_tierNotice(tier) case final notice?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: UIText.caption(
              notice,
              color: Colors.grey.shade600,
            ),
          ),

        // View Toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(
                value: 0,
                label: Text(
                  state is ManageMembersLoaded
                      ? 'Members (${state.members.length})'
                      : 'Members',
                ),
                icon: const Icon(Icons.people),
              ),
              ButtonSegment(
                value: 1,
                label: Text(
                  state is ManageMembersLoaded
                      ? 'Invitations (${state.pendingInvitations.length})'
                      : 'Invitations',
                ),
                icon: const Icon(Icons.mail_outline),
              ),
            ],
            selected: {_selectedTabIndex},
            onSelectionChanged: (Set<int> newSelection) {
              setState(() {
                _selectedTabIndex = newSelection.first;
              });
            },
            style: ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        const Divider(height: 1),

        // Content
        Expanded(
          child: state is ManageMembersLoading
              ? const Center(child: CircularProgressIndicator())
              : state is ManageMembersError
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(state.message),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              context.read<ManageMembersCubit>().loadData();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : state is ManageMembersLoaded
                      ? (_selectedTabIndex == 0
                          ? _MembersList(
                              state: state,
                              seatSummary: seatSummary,
                              canManageUsers: canManageUsers,
                            )
                          : _InvitationsList(
                              state: state,
                              canManageUsers: canManageUsers,
                            ))
                      : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Future<void> _showInviteMemberDialog(
    BuildContext context,
    ManageMembersLoaded state,
    SeatPricingSummary? seatSummary,
  ) async {
    // We need to use the context from the BlocProvider above to access the Cubit
    final cubit = context.read<ManageMembersCubit>();
    final adminCount = seatSummary?.summaryFor(UserRole.admin).total ?? 0;
    final practitionerCount =
        seatSummary?.summaryFor(UserRole.practitioner).total ?? 0;
    final adminLimit =
        seatSummary?.adminLimit ?? SeatPricingSummary.communityAdminSeatLimit;
    final practitionerLimit =
        seatSummary?.practitionerLimit ?? SeatPricingSummary.unlimitedSeats;
    final canAssignAdmin = _isWithinLimit(adminCount, adminLimit);
    final canAssignPractitioner =
        _isWithinLimit(practitionerCount, practitionerLimit);
    
    final result = await context.showSafeDialog<Map<String, String>?>(
      builder: (dialogContext) => _InviteMemberDialogContent(
        canAssignAdmin: canAssignAdmin,
        adminLimit: adminLimit,
        canAssignPractitioner: canAssignPractitioner,
        practitionerLimit: practitionerLimit,
        onShowSnackBar: (message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red)),
      ),
    );

    if (result != null) {
      final email = result['email']?.trim();
      final roleId = result['role'];
      if (email != null && email.isNotEmpty && roleId != null && roleId.isNotEmpty) {
        cubit.sendInvitation(email: email, roleId: roleId);
      }
    }
  }

  bool _isWithinLimit(int count, int limit) {
    return limit < 0 || count < limit;
  }

  String? _tierNotice(Tier tier) {
    switch (tier) {
      case Tier.community:
        return null;
      case Tier.pro:
        return 'Tier limits: 2 admins and 3 practitioners. Practitioner+ seats are included up to 3 before per-seat billing.';
      case Tier.scale:
        return 'No role limits on this tier. Practitioner+ seats are included up to 7 before per-seat billing.';
    }
  }
}

class _MembersList extends StatelessWidget {
  const _MembersList({
    required this.state,
    required this.seatSummary,
    required this.canManageUsers,
  });
  final ManageMembersLoaded state;
  final SeatPricingSummary? seatSummary;
  final bool canManageUsers;

  @override
  Widget build(BuildContext context) {
    if (state.members.isEmpty) {
      return const Center(child: Text('No members found.'));
    }

    return ListView.separated(
      padding: UI.paddingMd,
      itemCount: state.members.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final member = state.members[index];
        final isCurrentUser = member.id == state.currentUserId;
        final memberRole = _resolveMemberRole(member);
        
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            child: Text(
              member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
              style: TextStyle(color: Colors.blue.shade900),
            ),
          ),
          title: Row(
            children: [
              Flexible(child: Text(member.name.isNotEmpty ? member.name : 'Unknown User')),
              if (isCurrentUser) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'You',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(member.email),
                if (state.memberIntroNotes[member.id] case final introNote?)
                Text(introNote, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.admin_panel_settings, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(memberRole.label, style: TextStyle(color: Colors.grey.shade700)),
                ],
              ),
            ],
          ),
          trailing: isCurrentUser || !canManageUsers
              ? null
              : PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'remove') {
                      _confirmRemoveMember(context, member);
                    } else if (value == 'change_role') {
                       _showChangeRoleDialog(
                         context,
                         member,
                         memberRole,
                       );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'change_role',
                      child: Text('Change Role'),
                    ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _confirmRemoveMember(BuildContext context, User member) async {
     final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove ${member.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<ManageMembersCubit>().removeMember(member);
    }
  }

  Future<void> _showChangeRoleDialog(
    BuildContext context,
    User member,
    UserRole currentRole,
  ) async {
    final adminCount = seatSummary?.summaryFor(UserRole.admin).total ?? 0;
    final practitionerCount =
        seatSummary?.summaryFor(UserRole.practitioner).total ?? 0;
    final adminLimit =
        seatSummary?.adminLimit ?? SeatPricingSummary.communityAdminSeatLimit;
    final practitionerLimit =
        seatSummary?.practitionerLimit ?? SeatPricingSummary.unlimitedSeats;
    final canAssignAdmin =
        currentRole == UserRole.admin || _isWithinLimit(adminCount, adminLimit);
    final canAssignPractitioner = currentRole == UserRole.practitioner ||
        _isWithinLimit(practitionerCount, practitionerLimit);

    final newRoleId = await ChangeRoleDialog.show(
      context,
      memberName: member.name,
      initialRoleId: currentRole.id,
      canAssignAdmin: canAssignAdmin,
      adminLimit: adminLimit,
      canAssignPractitioner: canAssignPractitioner,
      practitionerLimit: practitionerLimit,
    );

    if (newRoleId != null && newRoleId != member.role && context.mounted) {
      context.read<ManageMembersCubit>().changeUserRole(member, newRoleId);
    }
  }

  UserRole _resolveMemberRole(User member) {
    return UserRole.fromId(member.role) ?? UserRole.practitioner;
  }

  bool _isWithinLimit(int count, int limit) {
    return limit < 0 || count < limit;
  }
}

class _InvitationsList extends StatelessWidget {
  const _InvitationsList({
    required this.state,
    required this.canManageUsers,
  });
  final ManageMembersLoaded state;
  final bool canManageUsers;

  @override
  Widget build(BuildContext context) {
     if (state.pendingInvitations.isEmpty) {
      return const Center(child: Text('No pending invitations.'));
    }

    return ListView.separated(
      padding: UI.paddingMd,
      itemCount: state.pendingInvitations.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final invitation = state.pendingInvitations[index];
         final expiresText = invitation.expiresAt != null
             // Simple formatting for now
            ? 'Expires: ${DateTime.parse(invitation.expiresAt!).toLocal().toString().substring(0, 10)}'
            : 'No expiry';

        return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.orange,
              child: Icon(Icons.person_add, color: Colors.white),
            ),
            title: Text(invitation.email),
            subtitle: Text(expiresText),
            trailing: IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: canManageUsers ? () => _confirmCancelInvitation(context, invitation) : null,
            ),
        );
      },
    );
  }

  Future<void> _confirmCancelInvitation(BuildContext context, Invitation invitation) async {
     final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Invitation'),
        content: Text('Cancel invitation for ${invitation.email}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<ManageMembersCubit>().cancelInvitation(invitation.id);
    }
  }
}

class _InviteMemberDialogContent extends StatefulWidget {
  const _InviteMemberDialogContent({
    required this.onShowSnackBar,
    required this.canAssignAdmin,
    required this.adminLimit,
    required this.canAssignPractitioner,
    required this.practitionerLimit,
  });
  final void Function(String message) onShowSnackBar;
  final bool canAssignAdmin;
  final int adminLimit;
  final bool canAssignPractitioner;
  final int practitionerLimit;

  @override
  State<_InviteMemberDialogContent> createState() => _InviteMemberDialogContentState();
}

class _InviteMemberDialogContentState extends State<_InviteMemberDialogContent> {
  late final TextEditingController _emailController;
  late String _selectedRole;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _selectedRole = _resolveInitialRole();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite New Member'),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            ...UserRole.values.map((role) {
                final isAdmin = role == UserRole.admin;
                final isPractitioner = role == UserRole.practitioner;
                final isEnabled = (!isAdmin || widget.canAssignAdmin) &&
                    (!isPractitioner || widget.canAssignPractitioner);
                final adminNote = isAdmin && !widget.canAssignAdmin
                    ? 'Admin seats are limited to ${_limitLabel(widget.adminLimit)}.'
                    : null;
                final practitionerNote =
                    isPractitioner && !widget.canAssignPractitioner
                        ? 'Practitioner seats are limited to ${_limitLabel(widget.practitionerLimit)}.'
                        : null;
                return RadioListTile<String>(
                  title: Text(role.label),
                  subtitle: Text(
                    adminNote ?? practitionerNote ?? role.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isEnabled ? Colors.grey.shade700 : Colors.grey.shade500,
                    ),
                  ),
                  value: role.id,
                  groupValue: _selectedRole,
                  onChanged: isEnabled
                      ? (val) {
                          if (val != null) {
                            setState(() => _selectedRole = val);
                          }
                        }
                      : null,
                );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_emailController.text.isEmpty) {
              widget.onShowSnackBar('Please enter an email address');
              return;
            }
            Navigator.pop(context, {'email': _emailController.text.trim(), 'role': _selectedRole});
          },
          child: const Text('Send'),
        ),
      ],
    );
  }

  String _resolveInitialRole() {
    final options = UserRole.values.where((role) {
      if (role == UserRole.admin) {
        return widget.canAssignAdmin;
      }
      if (role == UserRole.practitioner) {
        return widget.canAssignPractitioner;
      }
      return true;
    }).toList();
    return options.isNotEmpty ? options.first.id : UserRole.viewOnly.id;
  }

  String _limitLabel(int limit) {
    return limit < 0 ? 'Unlimited' : '$limit';
  }
}
