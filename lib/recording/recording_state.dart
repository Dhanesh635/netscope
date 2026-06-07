/// The reason a recording session failed to start or was aborted.
enum RecordingError {
  /// The device GPS service is switched off.
  locationServiceDisabled,

  /// The user denied location permission (can request again).
  locationPermissionDenied,

  /// The user permanently denied location permission (must open settings).
  locationPermanentlyDenied,

  /// The user denied READ_PHONE_STATE (signal metrics will be unavailable).
  phoneStatePermissionDenied,

  /// The user denied always-on / background location (recording will only
  /// work while the app is in the foreground).
  backgroundLocationDenied,
}

extension RecordingErrorX on RecordingError {
  /// Short, user-facing message for a SnackBar or inline banner.
  String get message {
    switch (this) {
      case RecordingError.locationServiceDisabled:
        return 'Location services are disabled. Please enable GPS to start recording.';
      case RecordingError.locationPermissionDenied:
        return 'Location permission is required to record a drive test.';
      case RecordingError.locationPermanentlyDenied:
        return 'Location permission is permanently denied. Open Settings to grant it.';
      case RecordingError.phoneStatePermissionDenied:
        return 'Phone-state permission denied. Signal metrics (RSRP/SINR) will be unavailable.';
      case RecordingError.backgroundLocationDenied:
        return 'Background location denied. Recording only works while the app is open.';
    }
  }

  /// Whether this error is a hard blocker (recording cannot start at all).
  bool get isBlocker {
    switch (this) {
      case RecordingError.locationServiceDisabled:
      case RecordingError.locationPermissionDenied:
      case RecordingError.locationPermanentlyDenied:
        return true;
      case RecordingError.phoneStatePermissionDenied:
      case RecordingError.backgroundLocationDenied:
        return false;
    }
  }
}

class RecordingState {
  const RecordingState({
    required this.isRecording,
    required this.isPaused,
    required this.sampleCount,
    required this.startTime,
    required this.elapsedDuration,
    this.lastError,
  });

  const RecordingState.idle()
      : isRecording = false,
        isPaused = false,
        sampleCount = 0,
        startTime = null,
        elapsedDuration = Duration.zero,
        lastError = null;

  final bool isRecording;
  final bool isPaused;
  final int sampleCount;
  final DateTime? startTime;
  final Duration elapsedDuration;

  /// The most recent error that prevented recording from starting or
  /// indicates a degraded mode (non-blocking). Null when no error.
  final RecordingError? lastError;

  RecordingState copyWith({
    bool? isRecording,
    bool? isPaused,
    int? sampleCount,
    DateTime? startTime,
    Duration? elapsedDuration,
    RecordingError? lastError,
    bool clearError = false,
  }) {
    return RecordingState(
      isRecording: isRecording ?? this.isRecording,
      isPaused: isPaused ?? this.isPaused,
      sampleCount: sampleCount ?? this.sampleCount,
      startTime: startTime ?? this.startTime,
      elapsedDuration: elapsedDuration ?? this.elapsedDuration,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}