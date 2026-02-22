// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/services/outplant_geometry_builder.dart';
import 'package:seafoundry_app/widgets/map/outplant_google_map.dart';

/// Lightweight preview helper that renders a geometry snapshot using the
/// existing Outplant map widget. Meant to keep the main section focused on form
/// wiring without duplicating the mapping logic from the outplant dialogs.
class _GeometryPreview extends StatelessWidget {
  const _GeometryPreview({
    required this.site,
    required this.geometryInput,
  });

  final Site? site;
  final OutplantGeometryInput? geometryInput;

  @override
  Widget build(BuildContext context) {
    if (geometryInput == null || site == null) {
      return Container(
        height: 48,
        alignment: Alignment.centerLeft,
        child: Text(
          'Geometry preview appears after entering valid coordinates.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).hintColor),
        ),
      );
    }

    try {
      final helper = OutplantGeometryBuilder();
      final geometry = helper.build(
        input: geometryInput!,
        siteCentroid: _siteCentroid(site),
      );
      final previewEvent = OutplantEvent.partial(
        geometry: geometry,
        name: 'Preview',
        siteId: site!.id,
        recordId: site!.id,
        recordModelType: ModelType.site,
        allocations: const <OutplantAllocation>[],
      );

      return SizedBox(
        height: 200,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: OutplantGoogleMap(
            outplantEvents: [previewEvent],
            monitoringEvents: const [],
            siteGeometry: site!.geometry,
            siteBounds: geometry.bounds ?? site!.geometry?.bounds,
            siteCentroid: geometry.centroid ?? _siteCentroid(site),
            showMonitoringMarkers: false,
            showKmlOverlays: true,
          ),
        ),
      );
    } catch (_) {
      return Container(
        height: 48,
        alignment: Alignment.centerLeft,
        child: Text(
          'Unable to preview geometry. Check coordinate format.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
  }

  static GeoCoordinate? _siteCentroid(Site? site) {
    if (site == null) return null;
    if (site.centroid != null) return site.centroid;
    if (site.geometry?.centroid != null) {
      return site.geometry!.centroid;
    }
    if (site.latitude != null && site.longitude != null) {
      return GeoCoordinate(latitude: site.latitude!, longitude: site.longitude!);
    }
    return null;
  }
}

/// Shared geometry capture section that mirrors the UX from the outplant event
/// dialog (manual coordinate entry + preview). KML upload support can be wired
/// in by providing the optional callbacks when other dialogs adopt it.
class GeometryCaptureSection extends StatelessWidget {
  const GeometryCaptureSection({
    super.key,
    required this.controller,
    required this.enabled,
    this.errorText,
    this.helperText,
    this.title = 'Geometry (optional)',
    this.site,
    this.geometryInput,
    this.onClear,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final String? helperText;
  final String title;
  final Site? site;
  final OutplantGeometryInput? geometryInput;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          helperText ??
              'Enter decimal degree coordinates (`lat,lng`) per line. A '
                  'preview renders once inputs are valid.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          enabled: enabled,
          maxLines: 4,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Coordinates',
            hintText: '24.51234,-80.41234',
            errorText: errorText,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        _GeometryPreview(site: site, geometryInput: geometryInput),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed:
                controller.text.isEmpty || !enabled ? null : onClear,
            child: const Text('Clear geometry'),
          ),
        ),
      ],
    );
  }
}
