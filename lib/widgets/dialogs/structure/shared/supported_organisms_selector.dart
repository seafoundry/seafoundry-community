// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/site_type.dart';

/// Simplified widget that always auto-selects coral (coral-only build).
/// Renders nothing since there is no organism selection needed.
class SupportedOrganismsSelector extends StatelessWidget {
  const SupportedOrganismsSelector({
    super.key,
    required this.formState,
    required this.organization,
  });

  final dynamic formState;
  final Organization organization;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/// Returns [OrganismKind.coral] as the only available organism.
List<OrganismKind> availableOrganismsForSelection(
  Organization organization,
  SiteType? siteType,
) {
  return const [OrganismKind.coral];
}
