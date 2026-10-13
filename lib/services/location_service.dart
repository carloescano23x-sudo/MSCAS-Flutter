import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() => _instance;

  LocationService._internal();

  Future<bool> hasPermission() async {
    PermissionStatus status = await Permission.location.status;

    if (!status.isGranted) {
      status = await Permission.location.request();
    }

    return status.isGranted;
  }

  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  Future<Position?> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return null;
      }

      PermissionStatus status = await Permission.location.status;

      if (!status.isGranted) {
        status = await Permission.location.request();

        if (!status.isGranted) {
          return null;
        }
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw Exception('Location request timed out');
        },
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> isWithinGeofence({
    required double userLatitude,
    required double userLongitude,
    required double classroomLatitude,
    required double classroomLongitude,
    required int radiusMeters,
  }) async {
    // Never treat missing/default coordinates as a valid geofence.
    if ((classroomLatitude == 0 && classroomLongitude == 0) ||
        radiusMeters <= 0) {
      return false;
    }

    final distance = Geolocator.distanceBetween(
      userLatitude,
      userLongitude,
      classroomLatitude,
      classroomLongitude,
    );

    return distance <= radiusMeters;
  }

  Future<double> getDistanceBetween({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) async {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
}
