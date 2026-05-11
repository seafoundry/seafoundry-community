import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/auth/auth_bloc.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/repositories/graph_repository.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/provenance_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/screens/spreadsheet/module_spreadsheet_screen.dart';
import 'package:seafoundry_app/services/csv_import_service.dart';
import 'package:seafoundry_app/screens/user/edit_user_profile_dialog.dart';
import 'package:seafoundry_app/theme/spacing.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';

/// Community edition app drawer providing module navigation, user profile, and sign-out.
class CommunityAppDrawer extends StatelessWidget {
  const CommunityAppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, theme),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildModuleTile(
                    context,
                    module: SpreadsheetModule.genetics,
                  ),
                  _buildModuleTile(
                    context,
                    module: SpreadsheetModule.inventory,
                  ),
                  _buildModuleTile(
                    context,
                    module: SpreadsheetModule.outplanting,
                  ),
                  const Divider(),
                  _buildProfileTile(context),
                  const Divider(),
                  _buildAboutTile(context),
                ],
              ),
            ),
            const Divider(height: 1),
            _buildSignOutTile(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return BlocBuilder<CurrentUser, CurrentUserState>(
      builder: (context, state) {
        final user = state is CurrentUserLoaded ? state.user : null;
        final org = state is CurrentUserLoaded ? state.organization : null;

        return Container(
          padding: EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primary,
                    backgroundImage: user?.imageUrl != null &&
                            user!.imageUrl!.isNotEmpty
                        ? NetworkImage(user.imageUrl!)
                        : null,
                    child: user?.imageUrl == null || user!.imageUrl!.isEmpty
                        ? Text(
                            user?.initials ?? '?',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                  SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'User',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (user?.email != null)
                          Text(
                            user!.email,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (org != null) ...[
                SizedBox(height: Spacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.business,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(width: Spacing.xs),
                    Expanded(
                      child: Text(
                        org.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildModuleTile(
    BuildContext context, {
    required SpreadsheetModule module,
  }) {
    return ListTile(
      leading: Icon(module.icon),
      title: Text(module.label),
      onTap: () => _openModule(context, module),
    );
  }

  void _openModule(BuildContext context, SpreadsheetModule module) {
    // Capture all providers from the drawer context BEFORE closing the drawer.
    // The drawer shares the scaffold's provider tree (endDrawer of
    // CommunitySimpleGraphScreenScaffold), so org-level repos are available.
    final navigator = Navigator.of(context);
    final currentUser = context.read<CurrentUser>();
    final userState = currentUser.state;
    if (userState is! CurrentUserLoaded) return;
    final organization = userState.organization;

    final organismRecordRepository =
        context.maybeRead<OrganismRecordRepository>();
    if (organismRecordRepository == null) return;

    final provenanceRepository = context.maybeRead<ProvenanceRepository>();
    final genetRepository = context.maybeRead<GenetRepository>();
    final groupRepository = context.maybeRead<GroupRepository>();
    final siteRepository = context.maybeRead<SiteRepository>();
    final eventRepository = context.maybeRead<EventRepository>();
    final graphRepository = context.maybeRead<GraphRepository>();
    final csvImportService = context.maybeRead<CSVImportService>();

    // Close drawer first, then push the module screen.
    navigator.pop();
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ModuleSpreadsheetScreen(
          module: module,
          organismRecordRepository: organismRecordRepository,
          organization: organization,
          currentUser: currentUser,
          provenanceRepository: provenanceRepository,
          genetRepository: genetRepository,
          groupRepository: groupRepository,
          siteRepository: siteRepository,
          eventRepository: eventRepository,
          graphRepository: graphRepository,
          csvImportService: csvImportService,
        ),
      ),
    );
  }

  Widget _buildProfileTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.person_outline),
      title: const Text('Edit Profile'),
      onTap: () {
        final state = context.read<CurrentUser>().state;
        Navigator.of(context).pop(); // Close drawer
        if (state is CurrentUserLoaded) {
          EditUserProfileDialog.show(context, state.user);
        }
      },
    );
  }

  Widget _buildAboutTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('About'),
      subtitle: const Text('SeaFoundry Community Edition'),
      onTap: () {
        Navigator.of(context).pop(); // Close drawer
        showAboutDialog(
          context: context,
          applicationName: 'SeaFoundry',
          applicationVersion: 'Community Edition',
          applicationLegalese: 'Open-source marine aquaculture platform',
          children: [
            const SizedBox(height: 16),
            const Text(
              'SeaFoundry helps coral restoration organizations '
              'manage genetics, inventory, and outplanting operations.',
            ),
          ],
        );
      },
    );
  }

  Widget _buildSignOutTile(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.logout,
        color: Theme.of(context).colorScheme.error,
      ),
      title: Text(
        'Sign Out',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      onTap: () {
        Navigator.of(context).pop(); // Close drawer
        context.read<AuthBloc>().signOut();
      },
    );
  }
}
