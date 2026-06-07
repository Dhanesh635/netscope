/// Identifies every runtime permission the app requires.
enum AppPermission {
  /// GPS / fine-location (while in use).
  location,

  /// Always-on / background location, needed for the background recording service.
  backgroundLocation,

  /// READ_PHONE_STATE – needed to read RSRP, RSRQ, SINR from the cellular modem.
  phoneState,
}

/// The lifecycle state of a single [AppPermission].
enum AppPermissionState {
  /// Initial state before any check has been performed.
  unknown,

  /// A check or request is currently in flight.
  checking,

  /// The permission has been granted.
  granted,

  /// The user denied the permission but did NOT select "Don't ask again".
  /// The app may request it again.
  denied,

  /// The user denied the permission and selected "Don't ask again".
  /// The app must direct the user to system settings.
  permanentlyDenied,

  /// The underlying system service is disabled (e.g. device GPS is off).
  serviceDisabled,
}

extension AppPermissionStateX on AppPermissionState {
  bool get isGranted => this == AppPermissionState.granted;
  bool get isDenied => this == AppPermissionState.denied;
  bool get isPermanentlyDenied => this == AppPermissionState.permanentlyDenied;
  bool get isServiceDisabled => this == AppPermissionState.serviceDisabled;

  /// True when the app cannot function for this permission and must show an error UI.
  bool get blocksUsage =>
      this == AppPermissionState.denied ||
      this == AppPermissionState.permanentlyDenied ||
      this == AppPermissionState.serviceDisabled;
}

extension AppPermissionX on AppPermission {
  /// Human-readable display name used in UI copy.
  String get displayName {
    switch (this) {
      case AppPermission.location:
        return 'Location';
      case AppPermission.backgroundLocation:
        return 'Background Location';
      case AppPermission.phoneState:
        return 'Phone State';
    }
  }

  /// One-line rationale shown to the user before the system dialog.
  String get rationale {
    switch (this) {
      case AppPermission.location:
        return 'NetScope needs your location to record the drive route and '
            'correlate signal measurements with GPS coordinates.';
      case AppPermission.backgroundLocation:
        return 'Background location lets NetScope continue recording signal '
            'data even when the screen is off or the app is in the background.';
      case AppPermission.phoneState:
        return 'NetScope reads your phone\'s cellular signal metrics '
            '(RSRP, RSRQ, SINR) to give you accurate 5G/LTE measurements.';
    }
  }
}
