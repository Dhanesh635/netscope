import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  const LocationService();

  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  Future<LocationPermission> requestGeolocatorPermission() {
    return Geolocator.requestPermission();
  }

  Future<PermissionStatus> requestAppPermission() {
    return Permission.locationWhenInUse.request();
  }

  Future<Position> getCurrentLocation() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 4),
      ),
    );
  }

  Stream<Position> getLocationStream() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    return Geolocator.getPositionStream(locationSettings: settings);
  }

  double? velocityFrom(Position position) {
    if (position.speed.isNaN) {
      return null;
    }

    return position.speed;
  }
}