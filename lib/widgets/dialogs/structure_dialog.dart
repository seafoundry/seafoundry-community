import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/graph/graph_node_streams.dart';
import 'package:seafoundry_app/cubits/group_creation/group_creation_bloc.dart';
import 'package:seafoundry_app/cubits/site_creation/site_creation_bloc.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/site_type.dart';
import 'package:seafoundry_app/repositories/graph_repository.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/widgets/dialogs/structure/group/group.dart';
import 'package:seafoundry_app/widgets/dialogs/structure/shared/parent_resolver.dart';
import 'package:seafoundry_app/widgets/dialogs/structure/shared/site_type_resolver.dart';
import 'package:seafoundry_app/widgets/dialogs/structure/shared/structure_dialog_helpers.dart';
import 'package:seafoundry_app/widgets/dialogs/structure/site/site.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';

import '../notifications/toast_overlay.dart';

export 'package:seafoundry_app/widgets/dialogs/structure/shared/structure_dialog_helpers.dart'
    show StructureType;

/// Unified dialog for creating sites and groups
///
/// This dialog consolidates structure creation operations (site, group) into
/// a single entry point. Previously these were separate dialogs (CreateSiteDialog,
/// CreateGroupDialog) that have been inlined into this unified implementation.
///
/// **Architecture**:
/// - Uses SiteCreationBloc for site creation with multi-step form
/// - Uses GroupCreationBloc for group creation with multi-step form
/// - Both flows use RecordFormStep pattern for wizard navigation
///
/// Usage:
/// ```dart
/// // Create a site (requires OrganizationNode parent)
/// await StructureDialog.show(
///   context,
///   type: StructureType.site,
/// );
///
/// // Create a group (requires SiteNode or GroupNode parent)
/// await StructureDialog.show(
///   context,
///   type: StructureType.group,
///   parentNode: siteNode,
/// );
/// ```
class StructureDialog {
  StructureDialog._();

  /// Show the structure creation dialog
  ///
  /// [type] determines whether to create a site or group
  /// [parentNode] is required for groups, ignored for sites (which are created at organization level)
  /// [existingSite] or [existingGroup] enable edit mode
  static Future<dynamic> show(
    BuildContext context, {
    required StructureType type,
    GraphNode? parentNode,
    Site? existingSite,
    Group? existingGroup,
    bool forceAllSiteTypes = false,
  }) async {
    switch (type) {
      case StructureType.site:
        return _showSiteDialog(
          context,
          existingSite: existingSite,
          forceAllSiteTypes: forceAllSiteTypes,
        );

      case StructureType.group:
        if (parentNode == null && existingGroup == null) {
          throw ArgumentError('parentNode is required when creating a group');
        }
        return _showGroupDialog(
          context,
          parentNode: parentNode,
          existingGroup: existingGroup,
        );
    }
  }

  /// Show structure dialog based on ModelType
  ///
  /// Convenience method that maps ModelType to StructureType
  /// and validates parent node requirements.
  static Future<dynamic> showForModelType(
    BuildContext context, {
    required ModelType modelType,
    GraphNode? parentNode,
    dynamic existingRecord,
    bool forceAllSiteTypes = false,
  }) async {
    switch (modelType) {
      case ModelType.site:
        return await show(
          context,
          type: StructureType.site,
          existingSite: existingRecord as Site?,
          forceAllSiteTypes: forceAllSiteTypes,
        );
      case ModelType.group:
        return await show(
          context,
          type: StructureType.group,
          parentNode: parentNode,
          existingGroup: existingRecord as Group?,
        );
      default:
        throw ArgumentError(
          'StructureDialog only supports site and group creation',
        );
    }
  }

  /// Show site creation dialog specifically for creating an outplanting site.
  ///
  /// This is a convenience method used when the user needs an outplanting site
  /// but none exist (e.g., when trying to create an outplant event).
  /// The dialog will be pre-configured with outplanting as the only available
  /// site type.
  static Future<Site?> showOutplantingSiteCreation(BuildContext context) async {
    return _showSiteDialog(context, forceSiteType: SiteType.outplanting);
  }

  static Future<Site?> _showSiteDialog(
    BuildContext context, {
    Site? existingSite,
    bool forceAllSiteTypes = false,
    SiteType? forceSiteType,
  }) async {
    final siteRepository = context.read<SiteRepository>();
    final graphRepository = context.read<GraphRepository>();
    final currentUser = context.maybeRead<CurrentUser>();

    final currentUserState = currentUser?.state;
    final organization = currentUserState is CurrentUserLoaded
        ? currentUserState.organization
        : siteRepository.organization;

    // Resolve available site types based on tier limits and configuration
    final existingSites = await siteRepository.getAll();
    final SiteTypeResolution resolution;
    if (forceSiteType != null) {
      // When a specific site type is forced, only allow that type
      resolution = SiteTypeResolution(
        availableSiteTypes: [forceSiteType],
        defaultSiteType: forceSiteType,
      );
    } else {
      resolution = await SiteTypeResolver.resolve(
        organization: organization,
        existingSites: existingSites,
        forceAllSiteTypes: forceAllSiteTypes,
        editingSite: existingSite,
      );
    }

    // Check mounted after async operation
    if (!context.mounted) return null;

    final allowBarrierDismissible =
        Theme.of(context).platform == TargetPlatform.iOS;
    return showDialog<Site>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: allowBarrierDismissible,
      builder: (dialogContext) {
        return MultiRepositoryProvider(
          providers: [
            RepositoryProvider.value(value: siteRepository),
            RepositoryProvider.value(value: graphRepository),
          ],
          child: BlocProvider(
            create: (_) {
              final bloc = SiteCreationBloc(
                siteRepository: siteRepository,
                initialSiteType: existingSite != null
                    ? SiteType.fromId(existingSite.siteTypeId)
                    : resolution.defaultSiteType,
              );
              if (existingSite != null) {
                bloc.initializeForEdit(existingSite);
              }
              return bloc;
            },
            child: SiteCreationDialog(
              organization: organization,
              graphRepository: graphRepository,
              availableSiteTypes: resolution.availableSiteTypes,
            ),
          ),
        );
      },
    );
  }

  /// Shows the group creation or edit dialog.
  ///
  /// **Parent Node Contract:**
  /// The dialog requires a valid [GraphNode] representing the parent structure
  /// for proper hierarchy display, group type filtering, and post-submission
  /// parent refresh. The parent node is resolved as follows:
  ///
  /// - **Creating a group:** [parentNode] is required and used directly
  /// - **Editing a group:** If [parentNode] is provided and matches the group's
  ///   parent, it's used. Otherwise, the parent node is loaded from
  ///   [GraphRepository] using the resolved parent record's urlPath.
  ///
  /// The dialog will show an error and abort if the parent cannot be resolved.
  static Future<void> _showGroupDialog(
    BuildContext context, {
    GraphNode? parentNode,
    Group? existingGroup,
  }) async {
    // Pre-capture repositories before showing dialog to avoid ProviderNotFoundException
    final groupRepository = context.read<GroupRepository>();
    final recordRepository = context.read<RecordRepository>();
    final graphRepository = context.read<GraphRepository>();

    // Resolve parent record and node
    final resolved = await ParentResolver.resolveParentForGroupDialog(
      parentNode: parentNode,
      existingGroup: existingGroup,
      recordRepository: recordRepository,
      graphRepository: graphRepository,
    );

    if (resolved == null) {
      if (context.mounted) {
        ToastOverlay.showSnackBar(
          context,
          const SnackBar(
            content: Text('Unable to load parent structure. Please try again.'),
          ),
        );
      }
      return;
    }

    final (groupParent, effectiveParentNode) = resolved;

    if (!context.mounted) return;

    final allowBarrierDismissible =
        Theme.of(context).platform == TargetPlatform.iOS;
    return showDialog(
      context: context,
      useRootNavigator: false,
      barrierDismissible: allowBarrierDismissible,
      builder: (dialogContext) {
        return RepositoryProvider.value(
          value: groupRepository,
          child: BlocProvider(
            create: (_) {
              final bloc = GroupCreationBloc(
                groupRepository: groupRepository,
                groupParent: groupParent,
                recordRepository: recordRepository,
              );
              if (existingGroup != null) {
                bloc.initializeForEdit(existingGroup);
              }
              return bloc;
            },
            child: GroupCreationDialog(parentNode: effectiveParentNode),
          ),
        );
      },
    );
  }
}
