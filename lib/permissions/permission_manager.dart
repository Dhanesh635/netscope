import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'app_permission.dart';

/// Central, observable permission manager.
///
/// Provides a single source of truth for every runtime permission the app
/// needs. Consumers should watch this via [ChangeNotifierProvider] and gate
/// their features on the relevant [AppPermissionState] property.
///
/// All state mutations happen on the main isolate so [notifyListeners] is
/// always safe to call.
class PermissionManager extends ChangeNotifier {
  AppPermissionState _locationState = AppPermissionState.unknown;
  AppPermissionState _backgroundLocationState = AppPermissionState.unknown;
  AppPermissionState _phoneStateState = AppPermissionState.unknown;

  // ── Public state ────────────────────────────────────────────────────────────

  AppPermissionState get locationState => _locationState;
  AppPermissionState get backgroundLocationState => _backgroundLocationState;
  AppPermissionState get phoneStateState => _phoneStateState;

  /// True when both location AND phone-state permissions are granted.
  /// These are the two permissions required to start a recording session.
  bool get allCriticalGranted =>
      _locationState.isGranted && _phoneStateState.isGranted;

  bool get locationGranted => _locationState.isGranted;
  bool get phoneStateGranted => _phoneStateState.isGranted;
  bool get backgroundLocationGranted => _backgroundLocationState.isGranted;

  // ── Convenience: state for a specific permission ─────────────────────────────

  AppPermissionState stateFor(AppPermission permission) {
    switch (permission) {
      case AppPermission.location:
        return _locationState;
      case AppPermission.backgroundLocation:
        return _backgroundLocationState;
      case AppPermission.phoneState:
        return _phoneStateState;
    }
  }

  // ── Initialisation & re-check ────────────────────────────────────────────────

  /// Silently checks every permission without showing system dialogs.
  /// Call this on app start and on resume.
  Future<void> checkAll() async {
    await Future.wait([
      _checkLocation(),
      _checkBackgroundLocation(),
      _checkPhoneState(),
    ]);
    notifyListeners();
  }

  // ── Request methods ──────────────────────────────────────────────────────────

  /// Requests foreground (while-in-use) location permission.
  ///
  /// Returns the resulting [AppPermissionState].
  Future<AppPermissionState> requestLocation() async {
    _locationState = AppPermissionState.checking;
    notifyListeners();

    // 1. Check whether the device GPS service itself is enabled.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _locationState = AppPermissionState.serviceDisabled;
      notifyListeners();
      return _locationState;
    }

    // 2. Use permission_handler as the unified backend.
    final status = await ph.Permission.locationWhenInUse.request();
    _locationState = _fromPhStatus(status);
    notifyListeners();
    return _locationState;
  }

  /// Requests background (always-on) location permission.
  ///
  /// Must only be called after foreground location has been granted.
  Future<AppPermissionState> requestBackgroundLocation() async {
    if (!_locationState.isGranted) {
      // Background location cannot be granted without foreground location.
      return _backgroundLocationState;
    }

    _backgroundLocationState = AppPermissionState.checking;
    notifyListeners();

    final status = await ph.Permission.locationAlways.request();
    _backgroundLocationState = _fromPhStatus(status);
    notifyListeners();
    return _backgroundLocationState;
  }

  /// Requests READ_PHONE_STATE permission.
  Future<AppPermissionState> requestPhoneState() async {
    _phoneStateState = AppPermissionState.checking;
    notifyListeners();

    final status = await ph.Permission.phone.request();
    _phoneStateState = _fromPhStatus(status);
    notifyListeners();
    return _phoneStateState;
  }

  /// Requests all critical permissions (location + phone state) in the correct
  /// order. Background location is requested last, only if foreground is granted.
  ///
  /// Returns true when ALL critical permissions (location + phone state) are granted.
  Future<bool> requestAll() async {
    await requestLocation();
    if (_locationState.isGranted) {
      await requestBackgroundLocation();
    }
    await requestPhoneState();
    return allCriticalGranted;
  }

  /// Opens the app's system settings page so the user can manually grant a
  /// permanently-denied permission.
  Future<void> openAppSettings() async {
    await ph.openAppSettings();
    // Re-check after the user returns from settings.
    await checkAll();
  }

  /// Opens the device location settings screen (used when the GPS service is off).
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
    await _checkLocation();
    notifyListeners();
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  Future<void> _checkLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _locationState = AppPermissionState.serviceDisabled;
      return;
    }

    final status = await ph.Permission.locationWhenInUse.status;
    _locationState = _fromPhStatus(status);
  }

  Future<void> _checkBackgroundLocation() async {
    final status = await ph.Permission.locationAlways.status;
    _backgroundLocationState = _fromPhStatus(status);
  }

  Future<void> _checkPhoneState() async {
    // On non-Android platforms phone state is not applicable — treat as granted
    // so it never blocks the UI.
    if (defaultTargetPlatform != TargetPlatform.android) {
      _phoneStateState = AppPermissionState.granted;
      return;
    }

    final status = await ph.Permission.phone.status;
    _phoneStateState = _fromPhStatus(status);
  }

  /// Maps a [permission_handler] [ph.PermissionStatus] to our [AppPermissionState].
  AppPermissionState _fromPhStatus(ph.PermissionStatus status) {
    switch (status) {
      case ph.PermissionStatus.granted:
      case ph.PermissionStatus.limited:
        return AppPermissionState.granted;
      case ph.PermissionStatus.denied:
        return AppPermissionState.denied;
      case ph.PermissionStatus.permanentlyDenied:
        return AppPermissionState.permanentlyDenied;
      case ph.PermissionStatus.restricted:
        // iOS "restricted" (parental controls) — treat as permanently denied
        // because the user cannot change it from within the app.
        return AppPermissionState.permanentlyDenied;
      case ph.PermissionStatus.provisional:
        return AppPermissionState.granted;
    }
  }
}
