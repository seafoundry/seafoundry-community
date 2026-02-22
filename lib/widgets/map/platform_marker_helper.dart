// @tier: community
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Platform-aware marker helper that provides colored markers on both mobile and web.
///
/// **Problem:** `BitmapDescriptor.defaultMarkerWithHue()` does not work on web.
/// All markers render as red regardless of the hue value specified.
///
/// **Solution:** This helper generates custom colored marker images on web
/// using Canvas, while continuing to use the native hue-based markers on mobile
/// where they work correctly.
///
/// **Usage:**
/// ```dart
/// final icon = await PlatformMarkerHelper.getMarkerIcon(BitmapDescriptor.hueGreen);
/// Marker(markerId: MarkerId('id'), position: position, icon: icon);
/// ```
class PlatformMarkerHelper {
  PlatformMarkerHelper._();

  /// Cache of generated marker icons to avoid regenerating on every call.
  static final Map<double, BitmapDescriptor> _iconCache = {};

  /// Mapping from hue values to Flutter colors for web marker generation.
  static final Map<double, Color> _hueToColor = {
    BitmapDescriptor.hueRed: Colors.red,
    BitmapDescriptor.hueOrange: Colors.orange,
    BitmapDescriptor.hueYellow: Colors.yellow,
    BitmapDescriptor.hueGreen: Colors.green,
    BitmapDescriptor.hueCyan: Colors.cyan,
    BitmapDescriptor.hueAzure: Colors.lightBlue,
    BitmapDescriptor.hueBlue: Colors.blue,
    BitmapDescriptor.hueViolet: Colors.purple,
    BitmapDescriptor.hueMagenta: Colors.pink,
    BitmapDescriptor.hueRose: Colors.pinkAccent,
  };

  /// Gets a marker icon for the specified hue value.
  ///
  /// On mobile platforms, uses the native `defaultMarkerWithHue` which works correctly.
  /// On web, generates a custom colored marker image using Canvas.
  ///
  /// Results are cached to avoid regenerating icons on every call.
  static Future<BitmapDescriptor> getMarkerIcon(double hue) async {
    // Check cache first
    if (_iconCache.containsKey(hue)) {
      return _iconCache[hue]!;
    }

    BitmapDescriptor icon;
    if (kIsWeb) {
      // Generate custom marker for web
      icon = await _generateWebMarker(hue);
    } else {
      // Use native hue-based marker on mobile
      icon = BitmapDescriptor.defaultMarkerWithHue(hue);
    }

    _iconCache[hue] = icon;
    return icon;
  }

  /// Clears the icon cache. Useful when you need to regenerate markers.
  static void clearCache() {
    _iconCache.clear();
  }

  /// Generates a custom marker image for web using Canvas.
  static Future<BitmapDescriptor> _generateWebMarker(double hue) async {
    final color = _getColorForHue(hue);
    const size = 48.0;
    const pinHeight = 60.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, size, pinHeight),
    );

    // Draw marker pin shape
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw the circular head
    final center = Offset(size / 2, size / 2 - 4);
    canvas.drawCircle(center, size / 2 - 2, paint);

    // Draw the pin point (triangle)
    final path = Path()
      ..moveTo(size / 2 - 12, size / 2 + 8)
      ..lineTo(size / 2 + 12, size / 2 + 8)
      ..lineTo(size / 2, pinHeight - 4)
      ..close();
    canvas.drawPath(path, paint);

    // Draw inner white circle for contrast
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size / 4 - 2, innerPaint);

    // Draw border
    final borderPaint = Paint()
      ..color = _darken(color, 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, size / 2 - 2, borderPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), pinHeight.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    if (bytes == null) {
      // Fallback to default marker if image generation fails
      return BitmapDescriptor.defaultMarker;
    }

    return BitmapDescriptor.bytes(Uint8List.view(bytes.buffer));
  }

  /// Maps a hue value to a Flutter Color.
  static Color _getColorForHue(double hue) {
    // Find the closest matching hue in our map
    double closestHue = BitmapDescriptor.hueRed;
    double minDiff = double.infinity;

    for (final knownHue in _hueToColor.keys) {
      final diff = (hue - knownHue).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestHue = knownHue;
      }
    }

    return _hueToColor[closestHue] ?? Colors.red;
  }

  /// Darkens a color by a given amount (0.0 to 1.0).
  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}

/// Extension to provide a synchronous fallback for cases where async isn't practical.
///
/// Use this when you need a marker icon synchronously but accept that web
/// markers may initially be red until the async version is loaded.
extension BitmapDescriptorPlatform on BitmapDescriptor {
  /// Returns a marker icon for the given hue.
  ///
  /// On mobile, this works correctly with colored markers.
  /// On web, this returns the default red marker (use async version for colors).
  static BitmapDescriptor platformMarkerWithHue(double hue) {
    // On mobile, defaultMarkerWithHue works correctly
    // On web, it returns red but this is a fallback for sync usage
    return BitmapDescriptor.defaultMarkerWithHue(hue);
  }
}
