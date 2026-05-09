import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/blocs/site_creation/site_creation_bloc.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/site_capabilities.dart';
import 'package:seafoundry_app/widgets/dialogs/structure/shared/supported_organisms_selector.dart';
import 'package:seafoundry_app/widgets/dialogs/structure/site/site_geometry_section.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

/// Site details step widget for the site creation dialog.
///
/// Collects site name, description, GPS coordinates, supported organisms,
/// and geometry data (for in-water sites). Includes validation feedback
/// for all required fields.
class SiteDetailsStepWidget extends StatelessWidget {
  const SiteDetailsStepWidget({
    super.key,
    required this.formState,
    required this.organization,
  });

  final SiteFormState formState;
  final Organization organization;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SiteCreationBloc>();
    final siteType = formState.siteType.value;
    final supportsGeometry = siteType != null
        ? SiteCapabilities.resolve(siteType).supportsGeometry
        : false;

    // Clear geometry state for non in-situ sites
    if (!supportsGeometry && formState.geometry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        bloc.add(const SiteGeometryCleared());
      });
    }

    return SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UIText.bodyMedium(
            'What is this ${formState.siteType.value?.name.toLowerCase() ?? 'site'} called?',
          ),
          UI.spacingVerticalMd,
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Site Name',
              hintText: 'Enter site name',
              prefixIcon: const Icon(Icons.location_on),
              border: const OutlineInputBorder(),
              errorText: formState.name.displayError?.message,
            ),
            initialValue: formState.name.value,
            onChanged: (value) {
              bloc.add(RecordNameChanged(value));
            },
            autofocus: true,
          ),
          UI.spacingVerticalMd,
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Description',
              hintText: 'Describe the site (optional)',
              border: const OutlineInputBorder(),
              errorText: formState.description.displayError?.message,
            ),
            initialValue: formState.description.value,
            maxLines: 3,
            onChanged: (value) {
              bloc.add(SiteDescriptionChanged(value));
            },
          ),
          UI.spacingVerticalMd,
          SupportedOrganismsSelector(
            formState: formState,
            organization: organization,
          ),
          UI.spacingVerticalMd,
          UIText.bodyMedium('Location (GPS Coordinates)'),
          UI.spacingVerticalSm,
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Latitude',
                    hintText: 'e.g., 25.7617',
                    border: const OutlineInputBorder(),
                    errorText: formState.locationLatitude.displayError?.message,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  initialValue: formState.locationLatitude.value,
                  onChanged: (value) {
                    bloc.add(SiteLatitudeChanged(value));
                  },
                ),
              ),
              UI.spacingHorizontalMd,
              Expanded(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Longitude',
                    hintText: 'e.g., -80.1918',
                    border: const OutlineInputBorder(),
                    errorText:
                        formState.locationLongitude.displayError?.message,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  initialValue: formState.locationLongitude.value,
                  onChanged: (value) {
                    bloc.add(SiteLongitudeChanged(value));
                  },
                ),
              ),
            ],
          ),
          if (supportsGeometry) ...[
            UI.spacingVerticalMd,
            SiteGeometrySection(formState: formState),
          ],
        ],
      ),
    );
  }
}
