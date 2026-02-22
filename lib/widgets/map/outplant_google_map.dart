// @tier: community
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/events/event.dart';
import '../../models/events/monitoring_event_record.dart';
import '../../services/logging_service.dart';
import '../../utils/geo_utils.dart';
import 'platform_marker_helper.dart';

/// Google Maps view used across outplant + monitoring workflows.
///
/// **Features:**
/// * Clusters outplant + monitoring markers when zoomed out (using bucket-based clustering)
/// * Visualizes site geometry (bounds, polygons, points, centroid)
/// * Shows parsed KML overlays (when available) with distinct orange styling
/// * Auto-fits the camera to the provided geometry/markers on init and widget updates
///
/// **Provider Requirements:**
/// - No providers required (pure widget, no context dependencies)
/// - Uses `GoogleMap` widget from `google_maps_flutter` package
///
/// **Navigation Note:**
/// Callers must handle `useRootNavigator: false` when showing dialogs so this
/// widget receives the proper `GoogleMapController`.
///
/// **Clustering Heuristics:**
/// - Markers within `_markerBucketSize` (0.02 degrees ≈ 2km) are grouped into clusters
/// - Clustered markers show count and average position
/// - Single markers show individual event details
/// - Clustering is applied separately for outplant and monitoring markers
///
/// **Camera Behavior:**
/// - Initial camera position derived from first available coordinate (outplant → site geometry → centroid → bounds)
/// - Falls back to Miami-ish coordinates if no data available
/// - Auto-fits camera to all geometry/markers after map creation (via post-frame callback)
/// - Camera fitting uses 60px padding and falls back to center+zoom if bounds calculation fails
///
/// **Styling Alignment:**
/// - Site geometry: Teal colors (matches `GeometryMap` preview)
/// - Outplant polygons: Indigo/blue colors
/// - KML overlays: Orange colors (distinct from regular polygons)
/// - Monitoring markers: Color-coded by health status (green=healthy, red=diseased, etc.)
/// - Site bounds: Blue-grey colors
class OutplantGoogleMap extends StatefulWidget {
  const OutplantGoogleMap({
    super.key,
    required this.outplantEvents,
    required this.monitoringEvents,
    this.siteGeometry,
    this.siteBounds,
    this.siteCentroid,
    this.showSiteBounds = true,
    this.showOutplantMarkers = true,
    this.showMonitoringMarkers = true,
    this.showKmlOverlays = true,
    this.onOutplantMarkerTap,
    this.onMonitoringMarkerTap,
    this.mapType = MapType.hybrid,
    this.myLocationButtonEnabled = true,
    this.mapToolbarEnabled = false,
  });

  final List<OutplantEvent> outplantEvents;
  final List<MonitoringEventRecord> monitoringEvents;
  final OutplantGeometry? siteGeometry;
  final GeoBounds? siteBounds;
  final GeoCoordinate? siteCentroid;
  final bool showSiteBounds;
  final bool showOutplantMarkers;
  final bool showMonitoringMarkers;
  final bool showKmlOverlays;
  final void Function(List<OutplantEvent> events)? onOutplantMarkerTap;
  final void Function(List<MonitoringEventRecord> events)?
  onMonitoringMarkerTap;
  final MapType mapType;
  final bool myLocationButtonEnabled;
  final bool mapToolbarEnabled;

  @override
  State<OutplantGoogleMap> createState() => _OutplantGoogleMapState();
}

class _OutplantGoogleMapState extends State<OutplantGoogleMap> {
  static const double _markerBucketSize = 0.02;
  static const CameraPosition _fallbackCamera = CameraPosition(
    target: LatLng(25.7617, -80.1918), // Miami-ish fallback
    zoom: 8,
  );
  static final Set<Factory<OneSequenceGestureRecognizer>> _gestureRecognizers =
      {Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())};

  final Completer<GoogleMapController> _controller = Completer();
  late CameraPosition _initialCamera;
  Set<Marker> _markers = const <Marker>{};
  Set<Polygon> _polygons = const <Polygon>{};
  Set<Circle> _circles = const <Circle>{};

  /// Cached marker icons for each hue value (for web platform support).
  final Map<double, BitmapDescriptor> _markerIconCache = {};

  @override
  void initState() {
    super.initState();
    _initialCamera = _deriveInitialCamera();
    _preloadMarkerIcons();
    _rebuildGeometry();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitCameraToData());
  }

  /// Pre-loads marker icons for all used colors to avoid async issues during marker building.
  Future<void> _preloadMarkerIcons() async {
    final hues = [
      BitmapDescriptor.hueAzure,
      BitmapDescriptor.hueGreen,
      BitmapDescriptor.hueBlue,
      BitmapDescriptor.hueOrange,
      BitmapDescriptor.hueRed,
      BitmapDescriptor.hueYellow,
    ];
    for (final hue in hues) {
      final icon = await PlatformMarkerHelper.getMarkerIcon(hue);
      if (mounted) {
        _markerIconCache[hue] = icon;
      }
    }
    // Rebuild geometry with proper icons after loading
    if (mounted) {
      _rebuildGeometry();
    }
  }

  @override
  void didUpdateWidget(covariant OutplantGoogleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rebuildGeometry();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitCameraToData());
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: _initialCamera,
      markers: _markers,
      polygons: _polygons,
      circles: _circles,
      gestureRecognizers: _gestureRecognizers,
      mapType: widget.mapType,
      myLocationButtonEnabled: widget.myLocationButtonEnabled,
      mapToolbarEnabled: widget.mapToolbarEnabled,
      onMapCreated: (controller) {
        if (!_controller.isCompleted) {
          _controller.complete(controller);
        }
      },
    );
  }

  CameraPosition _deriveInitialCamera() {
    final coordinate = _firstCoordinate();
    if (coordinate != null) {
      return CameraPosition(
        target: LatLng(coordinate.latitude, coordinate.longitude),
        zoom: 12,
      );
    }
    return _fallbackCamera;
  }

  GeoCoordinate? _firstCoordinate() {
    if (widget.outplantEvents.isNotEmpty) {
      final geometry = widget.outplantEvents.first.geometry;
      if (geometry != null) {
        final coord = geometry.centroid ?? geometry.coordinates.firstOrNull;
        if (_isValidCoordinate(coord)) return coord;
      }
    }
    if (widget.siteGeometry != null &&
        widget.siteGeometry!.coordinates.isNotEmpty) {
      final geometry = widget.siteGeometry!;
      final coord = geometry.centroid ?? geometry.coordinates.firstOrNull;
      if (_isValidCoordinate(coord)) return coord;
    }
    if (_isValidCoordinate(widget.siteCentroid)) {
      return widget.siteCentroid;
    }
    if (widget.siteBounds != null) {
      final bounds = widget.siteBounds!;
      if (!_isValidBounds(bounds)) return null;
      return GeoCoordinate(
        latitude: (bounds.northEast.latitude + bounds.southWest.latitude) / 2,
        longitude:
            (bounds.northEast.longitude + bounds.southWest.longitude) / 2,
      );
    }
    return null;
  }

  /// Rebuilds all map geometry (markers, polygons, circles) when inputs change.
  ///
  /// **Workflow:**
  /// 1. Builds outplant markers and polygons (if `showOutplantMarkers` is true)
  /// 2. Builds monitoring markers (if `showMonitoringMarkers` is true)
  /// 3. Builds site bounds polygon (if `showSiteBounds` is true and bounds exist)
  /// 4. Builds site geometry polygons and circles (if `siteGeometry` is provided)
  /// 5. Builds KML overlays (if `showKmlOverlays` is true)
  /// 6. Adds site centroid circle (if `siteCentroid` is provided)
  /// 7. Updates state with all collected geometry
  ///
  /// **Performance:**
  /// - Called in `initState` and `didUpdateWidget` to keep map in sync with props
  /// - All geometry is rebuilt from scratch (no incremental updates)
  /// - Clustering happens during marker building (see `_buildOutplantMarkers` and `_buildMonitoringMarkers`)
  void _rebuildGeometry() {
    if (!mounted) return;
    final markers = <Marker>{};
    final polygons = <Polygon>{};
    final circles = <Circle>{};

    if (widget.showOutplantMarkers) {
      markers.addAll(_buildOutplantMarkers(widget.outplantEvents));
      polygons.addAll(_buildOutplantPolygons(widget.outplantEvents));
    }

    if (widget.showMonitoringMarkers) {
      markers.addAll(_buildMonitoringMarkers(widget.monitoringEvents));
    }

    if (widget.showSiteBounds && widget.siteBounds != null) {
      final siteBoundsPolygon = _buildSiteBoundsPolygon(widget.siteBounds!);
      if (siteBoundsPolygon != null) {
        polygons.add(siteBoundsPolygon);
      }
    }

    if (widget.siteGeometry != null) {
      polygons.addAll(_buildSiteGeometryPolygons(widget.siteGeometry!));
      circles.addAll(_buildSiteGeometryCircles(widget.siteGeometry!));
    }

    if (widget.showKmlOverlays) {
      polygons.addAll(_buildKmlOverlays(widget.outplantEvents));
    }

    final centroid = widget.siteCentroid;
    if (centroid != null) {
      circles.add(
        Circle(
          circleId: const CircleId('site_centroid'),
          center: LatLng(centroid.latitude, centroid.longitude),
          radius: 8,
          fillColor: Colors.blueAccent.withValues(alpha: 0.25),
          strokeColor: Colors.blueAccent,
          strokeWidth: 1,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _markers = markers;
      _polygons = polygons;
      _circles = circles;
    });
  }

  /// Builds clustered outplant markers from events.
  ///
  /// **Clustering Algorithm:**
  /// - Groups markers into buckets based on `_bucketKey` (0.02 degree grid)
  /// - Markers in the same bucket are combined into a single cluster marker
  /// - Cluster position is the average of all contained marker positions
  /// - Cluster title shows count if multiple events, individual event name if single
  /// - Cluster snippet shows comma-separated event names for multi-event clusters
  ///
  /// **Styling:**
  /// - Uses `BitmapDescriptor.hueAzure` (blue) for all outplant markers
  /// - Info window shows event name and fragment count
  ///
  /// **Interaction:**
  /// - Marker tap calls `onOutplantMarkerTap` with all events in the cluster
  /// - Single-event markers show individual event details
  Iterable<Marker> _buildOutplantMarkers(List<OutplantEvent> events) {
    final buckets = <String, List<_MarkerCandidate>>{};

    for (final event in events) {
      final geometry = event.geometry;
      if (geometry == null) continue;
      final coord = geometry.centroid ?? geometry.coordinates.firstOrNull;
      if (!_isValidCoordinate(coord)) continue;
      final resolvedCoord = coord!;
      final key = _bucketKey(resolvedCoord, prefix: 'o');
      buckets
          .putIfAbsent(key, () => [])
          .add(
            _MarkerCandidate(
              coordinate: resolvedCoord,
              title: event.name,
              snippet: 'Outplant • ${event.totalQuantity} fragments',
              hue: BitmapDescriptor.hueAzure,
              outplantEvent: event,
            ),
          );
    }

    return buckets.entries.map((entry) {
      final candidates = entry.value;
      final averageLat =
          candidates.map((c) => c.coordinate.latitude).reduce((a, b) => a + b) /
          candidates.length;
      final averageLng =
          candidates
              .map((c) => c.coordinate.longitude)
              .reduce((a, b) => a + b) /
          candidates.length;

      final title = candidates.length == 1
          ? candidates.first.title
          : '${candidates.length} outplant events';
      final snippet = candidates.length == 1
          ? candidates.first.snippet
          : candidates.map((c) => c.title).join(', ');
      final eventsForMarker = candidates
          .map((c) => c.outplantEvent)
          .whereType<OutplantEvent>()
          .toList(growable: false);
      final hasTapHandler =
          eventsForMarker.isNotEmpty && widget.onOutplantMarkerTap != null;
      final tapHandler = hasTapHandler
          ? () => widget.onOutplantMarkerTap?.call(eventsForMarker)
          : null;
      final infoSnippet = _appendTapHint(snippet, hasTapHandler);

      // Use cached icon if available (for web support), fallback to default
      final icon =
          _markerIconCache[BitmapDescriptor.hueAzure] ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      return Marker(
        markerId: MarkerId(entry.key),
        position: LatLng(averageLat, averageLng),
        infoWindow: InfoWindow(
          title: title,
          snippet: infoSnippet,
          onTap: tapHandler,
        ),
        icon: icon,
        onTap: tapHandler,
        consumeTapEvents: tapHandler != null,
      );
    });
  }

  /// Builds clustered monitoring markers from events.
  ///
  /// **Clustering Algorithm:**
  /// - Groups markers into buckets based on `_bucketKey` (0.02 degree grid)
  /// - Markers in the same bucket are combined into a single cluster marker
  /// - Cluster position is the average of all contained marker positions
  /// - Cluster title shows count if multiple events, individual event name if single
  /// - Cluster snippet shows up to 3 event snippets joined with semicolons
  ///
  /// **Coordinate Resolution:**
  /// - Uses `_resolveMonitoringCoordinate` to find location (event geometry → outplant geometry → site centroid)
  /// - Health status determines marker color via `_healthHue`
  ///
  /// **Styling:**
  /// - Color-coded by health status: green (healthy), blue (recovering), orange (stressed), red (diseased), yellow (bleached)
  /// - Info window shows monitoring date, health status, and bleaching percentage
  ///
  /// **Interaction:**
  /// - Marker tap calls `onMonitoringMarkerTap` with all events in the cluster
  Iterable<Marker> _buildMonitoringMarkers(List<MonitoringEventRecord> events) {
    final buckets = <String, List<_MarkerCandidate>>{};

    for (final event in events) {
      final location = _resolveMonitoringCoordinate(event);
      if (!_isValidCoordinate(location)) continue;
      final resolvedLocation = location!;
      final key = _bucketKey(resolvedLocation, prefix: 'm');
      final healthLabel = event.newHealthStatus ?? event.healthStatus;
      final hue = _healthHue(healthLabel);
      buckets
          .putIfAbsent(key, () => [])
          .add(
            _MarkerCandidate(
              coordinate: resolvedLocation,
              title: event.outplantEventNameSnapshot ?? 'Monitoring',
              snippet: _buildMonitoringSnippet(event),
              hue: hue,
              monitoringEvent: event,
            ),
          );
    }

    return buckets.entries.map((entry) {
      final candidates = entry.value;
      final averageLat =
          candidates.map((c) => c.coordinate.latitude).reduce((a, b) => a + b) /
          candidates.length;
      final averageLng =
          candidates
              .map((c) => c.coordinate.longitude)
              .reduce((a, b) => a + b) /
          candidates.length;
      final title = candidates.length == 1
          ? candidates.first.title
          : '${candidates.length} monitoring entries';
      final snippet = candidates.length == 1
          ? candidates.first.snippet
          : candidates
                .map((c) => c.snippet)
                .whereType<String>()
                .take(3)
                .join('; ');
      final hue = candidates.map((c) => c.hue).reduce((a, b) => (a + b) / 2);
      final eventsForMarker = candidates
          .map((c) => c.monitoringEvent)
          .whereType<MonitoringEventRecord>()
          .toList(growable: false);
      final hasTapHandler =
          eventsForMarker.isNotEmpty && widget.onMonitoringMarkerTap != null;
      final tapHandler = hasTapHandler
          ? () => widget.onMonitoringMarkerTap?.call(eventsForMarker)
          : null;
      final infoSnippet = _appendTapHint(snippet, hasTapHandler);

      // Find closest cached icon for the averaged hue, or use fallback
      BitmapDescriptor icon = BitmapDescriptor.defaultMarkerWithHue(hue);
      double minDiff = double.infinity;
      for (final entry in _markerIconCache.entries) {
        final diff = (hue - entry.key).abs();
        if (diff < minDiff) {
          minDiff = diff;
          icon = entry.value;
        }
      }

      return Marker(
        markerId: MarkerId(entry.key),
        position: LatLng(averageLat, averageLng),
        infoWindow: InfoWindow(
          title: title,
          snippet: infoSnippet,
          onTap: tapHandler,
        ),
        icon: icon,
        onTap: tapHandler,
        consumeTapEvents: tapHandler != null,
      );
    });
  }

  Polygon? _buildSiteBoundsPolygon(GeoBounds bounds) {
    final points = _boundsToPoints(bounds);
    if (points.length < 3) return null;
    return Polygon(
      polygonId: const PolygonId('site_bounds'),
      points: points,
      strokeColor: Colors.blueGrey.shade600,
      strokeWidth: 2,
      fillColor: Colors.blueGrey.withValues(alpha: 0.08),
    );
  }

  Iterable<Polygon> _buildSiteGeometryPolygons(OutplantGeometry geometry) {
    final polygons = <Polygon>[];
    if (geometry.type == OutplantGeometryType.polygon &&
        geometry.coordinates.length >= 3) {
      final coordinates = _filterValidCoordinates(
        geometry.coordinates,
        source: 'site_geometry_polygon',
      );
      if (coordinates.length < 3) return polygons;
      polygons.add(
        Polygon(
          polygonId: const PolygonId('site_geometry_polygon'),
          points: coordinates
              .map((c) => LatLng(c.latitude, c.longitude))
              .toList(growable: false),
          strokeColor: Colors.teal.shade600,
          strokeWidth: 2,
          fillColor: Colors.teal.withValues(alpha: 0.15),
        ),
      );
    } else if (geometry.type == OutplantGeometryType.boundingBox &&
        geometry.bounds != null) {
      final points = _boundsToPoints(geometry.bounds!);
      if (points.length < 3) return polygons;
      polygons.add(
        Polygon(
          polygonId: const PolygonId('site_geometry_bounds'),
          points: points,
          strokeColor: Colors.teal.shade600,
          strokeWidth: 2,
          fillColor: Colors.teal.withValues(alpha: 0.12),
        ),
      );
    }
    return polygons;
  }

  Iterable<Circle> _buildSiteGeometryCircles(OutplantGeometry geometry) {
    final coordinates = _filterValidCoordinates(
      geometry.coordinates,
      source: 'site_geometry_points',
    );
    if (coordinates.isEmpty) {
      return const Iterable<Circle>.empty();
    }
    if (geometry.type != OutplantGeometryType.point &&
        geometry.type != OutplantGeometryType.multipoint) {
      return const Iterable<Circle>.empty();
    }

    final radius = geometry.type == OutplantGeometryType.point ? 8.0 : 12.0;
    final fillColor = Colors.tealAccent.withValues(alpha: 0.25);
    final strokeColor = Colors.teal.shade700;

    return List<Circle>.generate(coordinates.length, (index) {
      final coordinate = coordinates[index];
      return Circle(
        circleId: CircleId('site_geometry_point_$index'),
        center: LatLng(coordinate.latitude, coordinate.longitude),
        radius: radius,
        fillColor: fillColor,
        strokeColor: strokeColor,
        strokeWidth: 1,
      );
    });
  }

  Iterable<Polygon> _buildOutplantPolygons(List<OutplantEvent> events) {
    final polygons = <Polygon>{};
    for (final event in events) {
      final geometry = event.geometry;
      if (geometry == null) continue;
      if (geometry.bounds != null) {
        final points = _boundsToPoints(geometry.bounds!);
        if (points.length < 3) continue;
        polygons.add(
          Polygon(
            polygonId: PolygonId('${event.id}_bounds'),
            points: points,
            strokeColor: Colors.blueGrey.shade500,
            strokeWidth: 1,
            fillColor: Colors.blueGrey.withValues(alpha: 0.1),
          ),
        );
      } else if (geometry.type == OutplantGeometryType.polygon &&
          geometry.coordinates.length >= 3) {
        final coordinates = _filterValidCoordinates(
          geometry.coordinates,
          source: 'outplant_polygon:${event.id}',
        );
        if (coordinates.length < 3) continue;
        polygons.add(
          Polygon(
            polygonId: PolygonId(event.id),
            points: coordinates
                .map((c) => LatLng(c.latitude, c.longitude))
                .toList(growable: false),
            strokeColor: Colors.indigo,
            strokeWidth: 2,
            fillColor: Colors.indigo.withValues(alpha: 0.15),
          ),
        );
      }
    }
    return polygons;
  }

  /// Build polygons from KML attachments in outplant events.
  ///
  /// **Implementation Note**: Google Maps Flutter doesn't support KML layers directly,
  /// so we render KML geometry as native polygons using the coordinates already parsed
  /// and stored in the event geometry during KML file upload.
  ///
  /// **Styling**: KML overlays use distinct orange styling to differentiate them from
  /// regular outplant polygons (which use blue/indigo colors).
  ///
  /// **KML Attachment**: The presence of a KML attachment indicates that additional
  /// detail may be available in the original KML file (downloadable via signed URL).
  ///
  /// **Geometry Source**: KML geometry is parsed during upload and stored in the event's
  /// `OutplantGeometry` object, so we render it using the same logic as regular polygons.
  Iterable<Polygon> _buildKmlOverlays(List<OutplantEvent> events) {
    final polygons = <Polygon>[];
    for (final event in events) {
      final geometry = event.geometry;
      if (geometry == null || !geometry.hasKmlAttachment) continue;

      // KML geometry is already parsed and stored in the event geometry
      // We render it using the same logic as regular outplant polygons
      // but with distinct styling to indicate it came from KML
      if (geometry.bounds != null) {
        final points = _boundsToPoints(geometry.bounds!);
        if (points.length < 3) continue;
        polygons.add(
          Polygon(
            polygonId: PolygonId('${event.id}_kml_bounds'),
            points: points,
            strokeColor: Colors.orange.shade600,
            strokeWidth: 2,
            fillColor: Colors.orange.withValues(alpha: 0.15),
          ),
        );
      } else if (geometry.type == OutplantGeometryType.polygon &&
          geometry.coordinates.length >= 3) {
        final coordinates = _filterValidCoordinates(
          geometry.coordinates,
          source: 'kml_polygon:${event.id}',
        );
        if (coordinates.length < 3) continue;
        polygons.add(
          Polygon(
            polygonId: PolygonId('${event.id}_kml'),
            points: coordinates
                .map((c) => LatLng(c.latitude, c.longitude))
                .toList(growable: false),
            strokeColor: Colors.orange.shade600,
            strokeWidth: 2,
            fillColor: Colors.orange.withValues(alpha: 0.15),
          ),
        );
      }
    }
    return polygons;
  }

  /// Animates the camera to fit all known geometry/markers.
  ///
  /// **Workflow:**
  /// 1. Waits for `GoogleMapController` to be available
  /// 2. Collects all coordinates from events, site geometry, and bounds
  /// 3. Calculates bounding box (min/max lat/lng)
  /// 4. Animates camera to fit bounds with 60px padding
  /// 5. Falls back to center+zoom if bounds calculation fails
  ///
  /// **Timing:**
  /// - Called via `addPostFrameCallback` in `initState` and `didUpdateWidget`
  /// - Ensures map is fully initialized before attempting camera animation
  ///
  /// **Coordinate Sources:**
  /// - Site bounds (northEast, southWest)
  /// - Site geometry (coordinates, bounds, centroid)
  /// - Site centroid
  /// - Outplant event geometries (bounds, coordinates, centroid)
  /// - Monitoring event coordinates (resolved via `_resolveMonitoringCoordinate`)
  Future<void> _fitCameraToData() async {
    if (!mounted || !_controller.isCompleted) return;
    final controller = await _controller.future;
    final coordinates = _collectAllCoordinates();
    if (coordinates.isEmpty) return;

    double? minLat, maxLat, minLng, maxLng;
    for (final coord in coordinates) {
      minLat = minLat == null
          ? coord.latitude
          : math.min(minLat, coord.latitude);
      maxLat = maxLat == null
          ? coord.latitude
          : math.max(maxLat, coord.latitude);
      minLng = minLng == null
          ? coord.longitude
          : math.min(minLng, coord.longitude);
      maxLng = maxLng == null
          ? coord.longitude
          : math.max(maxLng, coord.longitude);
    }

    if (minLat == null || maxLat == null || minLng == null || maxLng == null) {
      return;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    try {
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
    } catch (e) {
      LoggingService.instance.warning(
        'Camera animation failed for bounds, falling back to center zoom: $e',
      );
      final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
      await controller.animateCamera(CameraUpdate.newLatLngZoom(center, 14));
    }
  }

  /// Returns every coordinate used for fitting bounds.
  Iterable<GeoCoordinate> _collectAllCoordinates() {
    final coordinates = <GeoCoordinate>[];
    if (widget.siteBounds != null) {
      final bounds = widget.siteBounds!;
      if (_isValidBounds(bounds)) {
        coordinates.add(bounds.southWest);
        coordinates.add(bounds.northEast);
      }
    }
    if (widget.siteGeometry != null) {
      final siteGeometry = widget.siteGeometry!;
      coordinates.addAll(
        _filterValidCoordinates(
          siteGeometry.coordinates,
          source: 'site_geometry',
        ),
      );
      if (siteGeometry.bounds != null) {
        final bounds = siteGeometry.bounds!;
        if (_isValidBounds(bounds)) {
          coordinates.add(bounds.southWest);
          coordinates.add(bounds.northEast);
        }
      }
      if (_isValidCoordinate(siteGeometry.centroid)) {
        coordinates.add(siteGeometry.centroid!);
      }
    }
    if (_isValidCoordinate(widget.siteCentroid)) {
      coordinates.add(widget.siteCentroid!);
    }
    for (final event in widget.outplantEvents) {
      final geometry = event.geometry;
      if (geometry == null) continue;
      if (geometry.bounds != null) {
        final bounds = geometry.bounds!;
        if (_isValidBounds(bounds)) {
          coordinates.add(bounds.southWest);
          coordinates.add(bounds.northEast);
        }
      }
      coordinates.addAll(
        _filterValidCoordinates(
          geometry.coordinates,
          source: 'outplant_geometry:${event.id}',
        ),
      );
      if (_isValidCoordinate(geometry.centroid)) {
        coordinates.add(geometry.centroid!);
      }
    }
    for (final monitoring in widget.monitoringEvents) {
      final coord = _resolveMonitoringCoordinate(monitoring);
      if (_isValidCoordinate(coord)) coordinates.add(coord!);
    }
    return coordinates;
  }

  /// Monitoring entries inherit geometry from their own record, the matching
  /// outplant event, or finally the site centroid.
  GeoCoordinate? _resolveMonitoringCoordinate(MonitoringEventRecord event) {
    // 1. Prefer the monitoring event's own geometry (e.g. specific point on reef)
    if (event.geometry != null) {
      final coord =
          event.geometry!.centroid ?? event.geometry!.coordinates.firstOrNull;
      if (_isValidCoordinate(coord)) return coord;
    }

    // 2. Fallback to the snapshot of the outplant geometry at time of monitoring
    final snapshotGeometry = event.outplantGeometry;
    if (snapshotGeometry != null) {
      final coord =
          snapshotGeometry.centroid ?? snapshotGeometry.coordinates.firstOrNull;
      if (_isValidCoordinate(coord)) return coord;
    }

    // 3. Fallback to the current outplant event geometry
    for (final outplant in widget.outplantEvents) {
      if (outplant.id == event.outplantEventId && outplant.geometry != null) {
        final coord =
            outplant.geometry!.centroid ??
            outplant.geometry!.coordinates.firstOrNull;
        if (_isValidCoordinate(coord)) return coord;
      }
    }

    // 4. Fallback to site centroid
    return widget.siteCentroid;
  }

  List<LatLng> _boundsToPoints(GeoBounds bounds) {
    if (!_isValidBounds(bounds)) {
      LoggingService.instance.warning(
        'OutplantGoogleMap: Skipping invalid bounds for map rendering',
      );
      return const <LatLng>[];
    }
    final sw = bounds.southWest;
    final ne = bounds.northEast;
    final nw = GeoCoordinate(latitude: ne.latitude, longitude: sw.longitude);
    final se = GeoCoordinate(latitude: sw.latitude, longitude: ne.longitude);
    return [
      LatLng(sw.latitude, sw.longitude),
      LatLng(nw.latitude, nw.longitude),
      LatLng(ne.latitude, ne.longitude),
      LatLng(se.latitude, se.longitude),
      LatLng(sw.latitude, sw.longitude),
    ];
  }

  double _healthHue(String? healthId) {
    switch (healthId) {
      case 'healthy':
        return BitmapDescriptor.hueGreen;
      case 'recovering':
        return BitmapDescriptor.hueBlue;
      case 'stressed':
        return BitmapDescriptor.hueOrange;
      case 'diseased':
        return BitmapDescriptor.hueRed;
      case 'bleached':
        return BitmapDescriptor.hueYellow;
      default:
        return BitmapDescriptor.hueAzure;
    }
  }

  String? _buildMonitoringSnippet(MonitoringEventRecord event) {
    final parts = <String>[];
    if (event.monitoringDate != null) {
      final date = event.monitoringDate!;
      parts.add(
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      );
    }
    if (event.newHealthStatus != null) {
      parts.add('Health: ${event.newHealthStatus}');
    }
    if (event.percentBleaching != null) {
      parts.add('Bleaching: ${event.percentBleaching?.toStringAsFixed(1)}%');
    }
    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }

  String _bucketKey(GeoCoordinate coordinate, {required String prefix}) {
    final latBucket = (coordinate.latitude / _markerBucketSize).round();
    final lngBucket = (coordinate.longitude / _markerBucketSize).round();
    return '${prefix}_${latBucket}_$lngBucket';
  }

  String? _appendTapHint(String? snippet, bool hasTapHandler) {
    if (!hasTapHandler) return snippet;
    const hint = 'Tap for details';
    if (snippet == null || snippet.isEmpty) return hint;
    return '$snippet\n$hint';
  }

  bool _isValidCoordinate(GeoCoordinate? coordinate) {
    if (coordinate == null) return false;
    final lat = coordinate.latitude;
    final lng = coordinate.longitude;
    if (!lat.isFinite || !lng.isFinite) return false;
    return GeoUtils.isValidLatitude(lat) && GeoUtils.isValidLongitude(lng);
  }

  bool _isValidBounds(GeoBounds bounds) {
    return _isValidCoordinate(bounds.southWest) &&
        _isValidCoordinate(bounds.northEast);
  }

  List<GeoCoordinate> _filterValidCoordinates(
    List<GeoCoordinate> coordinates, {
    required String source,
  }) {
    if (coordinates.isEmpty) return const <GeoCoordinate>[];
    final filtered = <GeoCoordinate>[];
    var dropped = 0;
    for (final coord in coordinates) {
      if (_isValidCoordinate(coord)) {
        filtered.add(coord);
      } else {
        dropped++;
      }
    }
    if (dropped > 0) {
      LoggingService.instance.warning(
        'OutplantGoogleMap: Dropped $dropped invalid coordinate(s) from $source.',
      );
    }
    return filtered;
  }
}

/// Internal helper used to cluster related markers before rendering.
class _MarkerCandidate {
  _MarkerCandidate({
    required this.coordinate,
    required this.title,
    this.snippet,
    required this.hue,
    this.outplantEvent,
    this.monitoringEvent,
  });

  final GeoCoordinate coordinate;
  final String title;
  final String? snippet;
  final double hue;
  final OutplantEvent? outplantEvent;
  final MonitoringEventRecord? monitoringEvent;
}

extension GeometryCoordinateList on List<GeoCoordinate> {
  GeoCoordinate? get firstOrNull => isEmpty ? null : first;
}
