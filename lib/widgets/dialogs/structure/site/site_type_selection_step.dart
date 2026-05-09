import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/blocs/site_creation/site_creation_bloc.dart';
import 'package:seafoundry_app/models/types/site_type.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';
import '../../components/dialog_scroll_view.dart';

/// Site type selection step widget for the site creation dialog.
///
/// Displays available site types as selectable cards. Auto-advances when
/// only one site type is available (typically outplanting for community tier).
class SiteTypeSelectionStep extends StatelessWidget {
  const SiteTypeSelectionStep({
    super.key,
    required this.formState,
    required this.availableSiteTypes,
  });

  final SiteFormState formState;
  final List<SiteType> availableSiteTypes;

  @override
  Widget build(BuildContext context) {
    // Handle case where limits are reached (no available site types)
    if (availableSiteTypes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24.0),
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            UI.spacingVerticalMd,
            UIText.h5('Site Limit Reached', textAlign: TextAlign.center),
            UI.spacingVerticalSm,
            UIText.bodyMedium(
              'You have reached the limit for site creation on the Community tier.\n\n'
              'Community organizations are limited to 1 nursery and 1 outplanting site. Upgrade your plan to create more sites.',
              textAlign: TextAlign.center,
              color: Colors.grey.shade700,
            ),
          ],
        ),
      );
    }

    // Auto-advance when only one site type available
    if (availableSiteTypes.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final bloc = context.read<SiteCreationBloc>();

        if (formState.siteType.value?.id != availableSiteTypes.first.id) {
          bloc.add(SiteTypeSelected(availableSiteTypes.first));
        } else {
          bloc.add(const RecordFormNextStep());
        }
      });
      return const SizedBox(
        width: 400,
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final bloc = context.read<SiteCreationBloc>();
    final selectedSiteType = formState.siteType.value;

    final updatedSelectedType = selectedSiteType ?? SiteType.nursery;

    return DialogScrollView(
      child: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UIText.bodyMedium('Select the type of site you want to create:'),
            UI.spacingVerticalMd,
            ...availableSiteTypes.map((siteType) {
              return _SiteTypeCard(
                siteType: siteType,
                isSelected: updatedSelectedType.id == siteType.id,
                onTap: () {
                  bloc.add(SiteTypeSelected(siteType));
                  bloc.add(const RecordFormNextStep());
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SiteTypeCard extends StatelessWidget {
  const _SiteTypeCard({
    required this.siteType,
    required this.isSelected,
    required this.onTap,
  });

  final SiteType siteType;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? Theme.of(context).secondaryHeaderColor : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(
              getSiteTypeIcon(siteType.id),
              color: isSelected ? Theme.of(context).primaryColor : null,
            ),
            title: Text(siteType.name),
            subtitle: Text(
              siteType.description,
              style: const TextStyle(fontSize: 12),
            ),
            selected: isSelected,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

/// Returns the appropriate icon for a site type.
IconData getSiteTypeIcon(String siteTypeId) {
  switch (siteTypeId) {
    case 'site_type_nursery':
      return Icons.warehouse;
    case 'site_type_outplanting':
      return Icons.terrain;
    default:
      return Icons.location_on;
  }
}
