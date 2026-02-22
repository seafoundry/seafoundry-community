// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/blocs/site_creation/site_creation_bloc.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/widgets/dialogs/structure/shared/review_field_row.dart';
import 'package:seafoundry_app/widgets/hierarchy_preview_widget.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

/// Site review step widget for the site creation dialog.
///
/// Displays a summary of all entered site information before submission,
/// including site type, name, group types, supported organisms, and
/// a hierarchy preview showing how the site fits in the organization.
class SiteReviewStepWidget extends StatelessWidget {
  const SiteReviewStepWidget({
    super.key,
    required this.formState,
    required this.organization,
  });

  final SiteFormState formState;
  final Organization organization;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UIText.h5('Review Your Site'),
          UI.spacingVerticalMd,
          ReviewFieldRow(
            label: 'Type',
            value: formState.siteType.value?.name ?? '',
          ),
          ReviewFieldRow(
            label: 'Name',
            value: formState.name.value ?? '',
          ),
          ReviewFieldRow(
            label: 'Group Types',
            value: formState.groupTypes.value?.isEmpty ?? true
                ? 'None'
                : formState.groupTypes.value?.map((g) => g.name).join(', ') ??
                    '',
          ),
          ReviewFieldRow(
            label: 'Supported Organisms',
            value: formState.supportedOrganisms.value?.isEmpty ?? true
                ? 'None'
                : formState.supportedOrganisms.value!
                    .map((kind) => kind.metadata.displayName)
                    .join(', '),
          ),
          UI.spacingVerticalMd,
          const Divider(),
          UI.spacingVerticalMd,
          HierarchyPreviewWidget(
            organizationName: organization.name,
            siteName: (formState.name.value?.isEmpty ?? true)
                ? 'New Site'
                : formState.name.value!,
            groupTypes: formState.groupTypes.value ?? [],
            isSiteNew: true,
          ),
        ],
      ),
    );
  }
}
