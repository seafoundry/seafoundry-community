// @tier: community
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:seafoundry_app/models/events/outplant_geometry.dart';
import 'package:seafoundry_app/services/logging_service.dart';

enum LocationStatus { success, permissionDenied, serviceDisabled, timeout, error }

class LocationResult {
  const LocationResult({this.coordinate, required this.status, this.errorMessage});

  final GeoCoordinate? coordinate;
  final LocationStatus status;
  final String? errorMessage;

  bool get isSuccess => status == LocationStatus.success && coordinate != null;
}

class LocationService {
  static final LocationService instance = LocationService._();
  LocationService._();

  Future<LocationResult> getCurrentPositionWithPermission() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(
          status: LocationStatus.serviceDisabled,
          errorMessage: 'Location services are disabled. Please enable GPS.',
        );
      }

      // Check/request permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationResult(
            status: LocationStatus.permissionDenied,
            errorMessage:
                'Location permission denied. Enable permissions or enter GPS manually.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          status: LocationStatus.permissionDenied,
          errorMessage:
              'Location permissions permanently denied. Enable in settings or enter GPS manually.',
        );
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      return LocationResult(
        status: LocationStatus.success,
        coordinate: GeoCoordinate(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } on TimeoutException {
      return const LocationResult(
        status: LocationStatus.timeout,
        errorMessage: 'GPS detection timed out. Try again or enter manually.',
      );
    } catch (e) {
      LoggingService.instance.error('Location detection failed', e);
      return LocationResult(
        status: LocationStatus.error,
        errorMessage: 'Failed to get location: $e',
      );
    }
  }
}
