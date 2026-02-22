// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/site_creation/site_creation_bloc.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/site_capabilities.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/models/types/site_type.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

/// Widget for selecting supported organisms for a site.
///
/// Handles tier-based filtering (Community tier auto-selects Coral only)
/// and provides organism selection chips for higher tiers.
class SupportedOrganismsSelector extends StatelessWidget {
  const SupportedOrganismsSelector({
    super.key,
    required this.formState,
    required this.organization,
  });

  final SiteFormState formState;
  final Organization organization;

  @override
  Widget build(BuildContext context) {
    final siteType = formState.siteType.value;
    final bloc = context.read<SiteCreationBloc>();
    final isCommunityTier = organization.tier == Tier.community;

    // Community tier: hide multi-organism selection, auto-select Coral only
    if (isCommunityTier) {
      // Auto-select Coral if not already selected
      final selected = formState.supportedOrganisms.value ?? const [];
      if (!selected.contains(OrganismKind.coral)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          bloc.add(const SiteSupportedOrganismsChanged([OrganismKind.coral]));
        });
      }
      // Don't show the organism selector for Community tier
      return const SizedBox.shrink();
    }

    final available = availableOrganismsForSelection(organization, siteType);
    final selected = formState.supportedOrganisms.value ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UIText.bodyMedium('Supported organisms'),
        UI.spacingVerticalSm,
        if (siteType == null)
          UIText.bodySmall(
            'Select a site type to configure supported organisms.',
            color: UI.textSecondaryColor,
          )
        else if (available.isEmpty)
          UIText.bodySmall(
            'No organisms are enabled for this site type.',
            color: UI.textSecondaryColor,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: available.map((kind) {
              final isSelected = selected.contains(kind);
              return FilterChip(
                label: Text(kind.metadata.displayName),
                selected: isSelected,
                onSelected: (value) => _toggleOrganismSelection(
                  context,
                  bloc,
                  kind,
                  value,
                  selected,
                ),
              );
            }).toList(),
          ),
        if (formState.supportedOrganisms.displayError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              formState.supportedOrganisms.displayError!.message,
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  void _toggleOrganismSelection(
    BuildContext context,
    SiteCreationBloc bloc,
    OrganismKind kind,
    bool shouldSelect,
    List<OrganismKind> currentSelection,
  ) {
    final next = List<OrganismKind>.from(currentSelection);
    if (shouldSelect) {
      if (!next.contains(kind)) next.add(kind);
    } else {
      if (next.length == 1 && next.first == kind) {
        showSafeDialogSnackBar(
          context,
          'Sites must support at least one organism.',
          isError: true,
        );
        return;
      }
      next.remove(kind);
    }
    bloc.add(SiteSupportedOrganismsChanged(next));
  }
}

/// Returns the list of organism kinds available for selection based on
/// organization configuration and site type capabilities.
///
/// Filtering logic:
/// 1. Gets organism kinds from organization's supported organisms
/// 2. If site type is specified, intersects with site type's allowed organisms
/// 3. Falls back to organization's organisms or site type's organisms if intersection is empty
List<OrganismKind> availableOrganismsForSelection(
  Organization organization,
  SiteType? siteType,
) {
  final orgKinds = organization.supportedOrganismKinds;
  if (siteType == null) {
    return orgKinds;
  }
  final allowed = SiteCapabilities.resolve(siteType).supportedOrganisms;
  final intersection = allowed
      .where((kind) => orgKinds.contains(kind))
      .toList();
  if (intersection.isNotEmpty) {
    intersection.sort(
      (a, b) => a.metadata.displayName.compareTo(b.metadata.displayName),
    );
    return intersection;
  }
  final fallback = orgKinds.isNotEmpty ? orgKinds : allowed.toList();
  fallback.sort(
    (a, b) => a.metadata.displayName.compareTo(b.metadata.displayName),
  );
  return fallback;
}
