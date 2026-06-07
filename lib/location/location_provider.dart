import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../permissions/app_permission.dart';
import '../permissions/permission_manager.dart';
import 'location_service.dart';

/// Tracks the device's current GPS position and exposes it as a stream.
///
/// Location permission management is fully delegated to [PermissionManager].
/// This class only starts/stops the position stream — it never asks for
/// permissions itself.
class LocationProvider extends ChangeNotifier {
  LocationProvider({
    required PermissionManager permissionManager,
    LocationService? locationService,
  })  : _permissionManager = permissionManager,
        _locationService = locationService ?? const LocationService();

  final PermissionManager _permissionManager;
  final LocationService _locationService;

  bool _isTracking = false;
  Position? _currentPosition;
  double? _velocity;
  StreamSubscription<Position>? _subscription;

  bool get isTracking => _isTracking;
  Position? get currentPosition => _currentPosition;
  double? get velocity => _velocity;

  /// Whether location permission is currently granted.
  bool get isPermissionGranted =>
      _permissionManager.stateFor(AppPermission.location).isGranted;

  /// The current location permission state from the manager.
  AppPermissionState get locationPermissionState =>
      _permissionManager.stateFor(AppPermission.location);

  /// Begins listening for position updates.
  ///
  /// If location permission is not yet granted, the method checks current
  /// state and starts the stream only when the permission becomes available.
  /// This is safe to call at startup regardless of permission state.
  Future<void> startTracking() async {
    // Perform a silent check so the manager has fresh state.
    await _permissionManager.checkAll();

    if (!_permissionManager.locationGranted) {
      // Listen for the manager to notify us when the user grants permission
      // (e.g. from the PermissionGate widget).
      _permissionManager.addListener(_onPermissionChanged);
      notifyListeners();
      return;
    }

    await _startStream();
  }

  Future<void> stopTracking() async {
    _permissionManager.removeListener(_onPermissionChanged);
    await _subscription?.cancel();
    _subscription = null;
    _isTracking = false;
    notifyListeners();
  }

  void _onPermissionChanged() {
    if (_permissionManager.locationGranted && !_isTracking) {
      _permissionManager.removeListener(_onPermissionChanged);
      _startStream();
    }
  }

  Future<void> _startStream() async {
    await _subscription?.cancel();
    _isTracking = true;
    notifyListeners();

    _subscription = _locationService.getLocationStream().listen(
      (position) {
        _currentPosition = position;
        _velocity = _locationService.velocityFrom(position);
        notifyListeners();
      },
      onError: (Object error) {
        // Stream errors (e.g. permission revoked mid-session) are caught here
        // so they never propagate as unhandled exceptions.
        _isTracking = false;
        _subscription = null;
        notifyListeners();
        debugPrint('LocationProvider stream error: $error');
      },
      cancelOnError: true,
    );
  }

  @override
  void dispose() {
    _permissionManager.removeListener(_onPermissionChanged);
    _subscription?.cancel();
    super.dispose();
  }
}