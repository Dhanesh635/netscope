import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../data/measurement_repository.dart';
import '../models/network_measurement.dart';
import '../permissions/app_permission.dart';
import '../permissions/permission_manager.dart';
import '../services/network_service.dart';
import '../services/speed_test_service.dart';
import 'recording_state.dart';

class RecordingService extends ChangeNotifier {
  RecordingService({
    required PermissionManager permissionManager,
    MeasurementRepository? measurementRepository,
  })  : _permissionManager = permissionManager,
        _measurementRepository =
            measurementRepository ?? MeasurementRepository() {
    _initializeBackgroundListener();
  }

  final PermissionManager _permissionManager;
  final MeasurementRepository _measurementRepository;
  final NetworkService _networkService = NetworkService();

  RecordingState _state = const RecordingState.idle();
  RecordingState get state => _state;

  int? _sessionId;
  DateTime? _pauseStartedAt;
  Duration _pausedDuration = Duration.zero;
  final List<NetworkMeasurement> _capturedMeasurements = <NetworkMeasurement>[];

  List<NetworkMeasurement> get capturedMeasurements =>
      List.unmodifiable(_capturedMeasurements);

  NetworkMeasurement? get latestMeasurement =>
      _capturedMeasurements.isEmpty ? null : _capturedMeasurements.last;

  void _initializeBackgroundListener() {
    try {
      FlutterBackgroundService().on('onMeasurementCaptured').listen((event) {
        if (event == null) return;
        final measurement = NetworkMeasurement.fromMap(event);
        _capturedMeasurements.add(measurement);

        _state = _state.copyWith(
          sampleCount: _state.sampleCount + 1,
          elapsedDuration: _elapsedSinceStart(),
          clearError: true,
        );
        notifyListeners();
      });

      FlutterBackgroundService().on('requestSessionId').listen((_) {
        if (_sessionId != null) {
          FlutterBackgroundService().invoke('setSessionId', {'sessionId': _sessionId});
        }
      });

      // Respond to signal info requests from the background isolate.
      // The MethodChannel for 'netscope/network' only works in the foreground
      // engine, so the background asks us and we reply via IPC.
      FlutterBackgroundService().on('requestSignalInfo').listen((_) async {
        try {
          final info = await _networkService.getCurrentSignalInfo();
          FlutterBackgroundService().invoke(
            'signalInfoResponse',
            info.toMap(),
          );
        } catch (e) {
          debugPrint('RecordingService: error responding to signal request — $e');
        }
      });

      // Respond to speed test requests from the background isolate.
      FlutterBackgroundService().on('requestSpeedTest').listen((_) async {
        try {
          final speedTest = SpeedTestService();
          final result = await speedTest.runFullTest();
          FlutterBackgroundService().invoke('speedTestResponse', {
            'download': result.download,
            'upload': result.upload,
          });
          speedTest.dispose();
        } catch (e) {
          debugPrint('RecordingService: error responding to speed test — $e');
          FlutterBackgroundService().invoke('speedTestResponse', {
            'download': null,
            'upload': null,
          });
        }
      });
    } catch (e) {
      // FlutterBackgroundService throws on unsupported platforms (e.g. widget tests)
      debugPrint('Skipping background service listener initialization: $e');
    }
  }

  Future<void> startRecording() async {
    if (_state.isRecording) return;

    // ── 1. Check location permission ──────────────────────────────────────────
    final locationState =
        _permissionManager.stateFor(AppPermission.location);

    if (locationState.isServiceDisabled) {
      _state = _state.copyWith(
        lastError: RecordingError.locationServiceDisabled,
        clearError: false,
      );
      notifyListeners();
      return;
    }

    if (locationState.isPermanentlyDenied) {
      _state = _state.copyWith(
        lastError: RecordingError.locationPermanentlyDenied,
        clearError: false,
      );
      notifyListeners();
      return;
    }

    if (!locationState.isGranted) {
      // Try to request it now.
      final result = await _permissionManager.requestLocation();
      if (result.isServiceDisabled) {
        _state = _state.copyWith(
          lastError: RecordingError.locationServiceDisabled,
          clearError: false,
        );
        notifyListeners();
        return;
      }
      if (result.isPermanentlyDenied) {
        _state = _state.copyWith(
          lastError: RecordingError.locationPermanentlyDenied,
          clearError: false,
        );
        notifyListeners();
        return;
      }
      if (!result.isGranted) {
        _state = _state.copyWith(
          lastError: RecordingError.locationPermissionDenied,
          clearError: false,
        );
        notifyListeners();
        return;
      }
    }

    // ── 2. Check phone-state permission (non-blocking) ────────────────────────
    final phoneState =
        _permissionManager.stateFor(AppPermission.phoneState);
    if (!phoneState.isGranted) {
      final result = await _permissionManager.requestPhoneState();
      if (!result.isGranted) {
        // Non-blocking: recording continues but stores a warning in state.
        _state = _state.copyWith(
          lastError: RecordingError.phoneStatePermissionDenied,
          clearError: false,
        );
        notifyListeners();
        // Do NOT return — recording proceeds with fallback signal values.
      }
    }

    // ── 3. Check background location (non-blocking) ───────────────────────────
    final bgState =
        _permissionManager.stateFor(AppPermission.backgroundLocation);
    if (!bgState.isGranted && defaultTargetPlatform == TargetPlatform.android) {
      _state = _state.copyWith(
        lastError: RecordingError.backgroundLocationDenied,
        clearError: false,
      );
      notifyListeners();
    }

    // ── 4. Start the session ──────────────────────────────────────────────────
    _pausedDuration = Duration.zero;
    _pauseStartedAt = null;
    _capturedMeasurements.clear();

    final startedAt = DateTime.now();
    _sessionId = await _measurementRepository.createSession(
      startedAt: startedAt,
    );
    debugPrint('[RecordingService] Session created: ID=$_sessionId');

    _state = RecordingState(
      isRecording: true,
      isPaused: false,
      sampleCount: 0,
      startTime: startedAt,
      elapsedDuration: Duration.zero,
      lastError: _state.lastError, // carry over non-blocking warnings
    );
    notifyListeners();

    // ── 5. Ensure notification permission (required on Android 13+) ──────────
    if (defaultTargetPlatform == TargetPlatform.android) {
      final notifStatus = await ph.Permission.notification.status;
      debugPrint('[RecordingService] Notification permission: $notifStatus');
      if (!notifStatus.isGranted) {
        final result = await ph.Permission.notification.request();
        debugPrint('[RecordingService] Notification permission after request: $result');
      }
    }

    // ── 6. Start background service ──────────────────────────────────────────
    final service = FlutterBackgroundService();
    final wasRunning = await service.isRunning();
    debugPrint('[RecordingService] Background service isRunning=$wasRunning');

    // Always stop and restart to ensure a clean Dart isolate with fresh state.
    if (wasRunning) {
      debugPrint('[RecordingService] Stopping stale service before restart...');
      service.invoke('stopService');
      await Future.delayed(const Duration(milliseconds: 500));
    }

    try {
      await service.startService();
      debugPrint('[RecordingService] startService() completed');
    } catch (e) {
      debugPrint('[RecordingService] startService() FAILED: $e');
    }
    // Wait for the background isolate to spin up and register listeners
    await Future.delayed(const Duration(milliseconds: 1500));

    final isRunningAfter = await service.isRunning();
    debugPrint('[RecordingService] Background service isRunning (after start)=$isRunningAfter');

    if (!isRunningAfter) {
      await _failStart(
        sessionId: _sessionId,
        error: RecordingError.backgroundServiceStartFailed,
      );
      return;
    }

    service.invoke('setSessionId', {'sessionId': _sessionId});
    debugPrint('[RecordingService] Sent setSessionId=$_sessionId to background service');
  }

  Future<void> pauseRecording() async {
    if (!_state.isRecording || _state.isPaused) return;

    _pauseStartedAt = DateTime.now();
    _state = _state.copyWith(
      isPaused: true,
      elapsedDuration: _elapsedSinceStart(),
    );
    notifyListeners();

    FlutterBackgroundService().invoke('setSessionId', {'sessionId': null});
  }

  Future<void> resumeRecording() async {
    if (!_state.isRecording || !_state.isPaused) return;

    if (_pauseStartedAt != null) {
      _pausedDuration += DateTime.now().difference(_pauseStartedAt!);
    }
    _pauseStartedAt = null;

    _state = _state.copyWith(
      isPaused: false,
      elapsedDuration: _elapsedSinceStart(),
    );
    notifyListeners();

    FlutterBackgroundService().invoke('setSessionId', {
      'sessionId': _sessionId,
    });
  }

  Future<void> stopRecording() async {
    if (!_state.isRecording) return;

    if (_pauseStartedAt != null) {
      _pausedDuration += DateTime.now().difference(_pauseStartedAt!);
      _pauseStartedAt = null;
    }

    final endedAt = DateTime.now();
    debugPrint('[RecordingService] Stop — Session=$_sessionId, Samples=${_capturedMeasurements.length}');

    // Stop background isolate first, wait for in-flight inserts, then close the session.
    FlutterBackgroundService().invoke('stopService');
    await Future.delayed(const Duration(milliseconds: 600));

    if (_sessionId != null) {
      await _measurementRepository.closeSession(_sessionId!, endedAt: endedAt);
    }

    _state = _state.copyWith(
      isRecording: false,
      isPaused: false,
      elapsedDuration: _elapsedSinceStart(finalMoment: endedAt),
      clearError: true,
    );
    notifyListeners();

    _sessionId = null;
    _pausedDuration = Duration.zero;
  }

  Duration _elapsedSinceStart({DateTime? finalMoment}) {
    final startedAt = _state.startTime;
    if (startedAt == null) return Duration.zero;

    final moment = finalMoment ?? DateTime.now();
    final pausedDuration =
        _pausedDuration +
        (_pauseStartedAt == null
            ? Duration.zero
            : moment.difference(_pauseStartedAt!));
    final elapsed = moment.difference(startedAt) - pausedDuration;
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  Future<void> _failStart({
    required int? sessionId,
    required RecordingError error,
  }) async {
    if (sessionId != null) {
      try {
        await _measurementRepository.closeSession(sessionId);
      } catch (e) {
        debugPrint('[RecordingService] Failed to close aborted session: $e');
      }
    }

    _sessionId = null;
    _pauseStartedAt = null;
    _pausedDuration = Duration.zero;
    _capturedMeasurements.clear();
    _state = const RecordingState.idle().copyWith(
      lastError: error,
      clearError: false,
    );
    notifyListeners();
  }
}
