import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../services/csv_recording_service.dart';
import '../models/network_measurement.dart';
import '../permissions/app_permission.dart';
import '../permissions/permission_manager.dart';
import '../services/network_service.dart';
import '../services/speed_test_service.dart';
import 'recording_state.dart';
import '../services/prediction_service.dart';

class RecordingService extends ChangeNotifier {
  RecordingService({
    required PermissionManager permissionManager,
  })  : _permissionManager = permissionManager {
    _initializeBackgroundListener();
  }

  final PermissionManager _permissionManager;
  final NetworkService _networkService = NetworkService();
  final CsvRecordingService _csvRecordingService = CsvRecordingService();

  RecordingState _state = const RecordingState.idle();
  RecordingState get state => _state;

  String? _activeCsvPath;
  DateTime? _pauseStartedAt;
  Duration _pausedDuration = Duration.zero;
  final List<NetworkMeasurement> _capturedMeasurements = <NetworkMeasurement>[];

  List<NetworkMeasurement> get capturedMeasurements =>
      List.unmodifiable(_capturedMeasurements);

  NetworkMeasurement? get latestMeasurement =>
      _capturedMeasurements.isEmpty ? null : _capturedMeasurements.last;

  /// The previous measurement — second-to-last in the captured list.
  NetworkMeasurement? get previousMeasurement =>
      _capturedMeasurements.length < 2 ? null : _capturedMeasurements[_capturedMeasurements.length - 2];

  /// The active CSV file path for the current session. Null when not recording.
  String? get activeCsvPath => _activeCsvPath;

  void _initializeBackgroundListener() {
    try {
      FlutterBackgroundService().on('onMeasurementCaptured').listen((event) async {
        if (event == null) return;
        final measurement = NetworkMeasurement.fromMap(event);

final ai = await PredictionService.instance.predict(measurement);

final enriched = NetworkMeasurement(
  id: measurement.id,
  sessionId: measurement.sessionId,
  deviceId: measurement.deviceId,
  deviceMake: measurement.deviceMake,
  deviceModel: measurement.deviceModel,
  timestamp: measurement.timestamp,
  latitude: measurement.latitude,
  longitude: measurement.longitude,
  rsrp: measurement.rsrp,
  rsrq: measurement.rsrq,
  sinr: measurement.sinr,
  download: measurement.download,
  upload: measurement.upload,
  pci: measurement.pci,
  carrier: measurement.carrier,
  networkType: measurement.networkType,
  velocity: measurement.velocity,

  handoverProbability: ai?.probability,
  prediction: ai?.prediction,
  riskLevel: ai?.riskLevel,
  qosScore: ai?.qosScore,
);
await _csvRecordingService.appendMeasurement(enriched);
_capturedMeasurements.add(enriched);

_state = _state.copyWith(
  sampleCount: _state.sampleCount + 1,
  elapsedDuration: _elapsedSinceStart(),
  clearError: true,
);

notifyListeners();
      });

      FlutterBackgroundService().on('requestCsvPath').listen((_) {
        if (_activeCsvPath != null) {
          FlutterBackgroundService().invoke('setCsvPath', {'csvPath': _activeCsvPath});
        }
      });

      // Respond to signal info requests from the background isolate.
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
        _state = _state.copyWith(
          lastError: RecordingError.phoneStatePermissionDenied,
          clearError: false,
        );
        notifyListeners();
      }
    }

    // ── 3. Check background location (non-blocking) ───────────────────────────
    final bgState =
        _permissionManager.stateFor(AppPermission.backgroundLocation);
    if (!bgState.isGranted && defaultTargetPlatform == TargetPlatform.android) {
      final result = await _permissionManager.requestBackgroundLocation();
      if (!result.isGranted) {
        _state = _state.copyWith(
          lastError: RecordingError.backgroundLocationDenied,
          clearError: false,
        );
        notifyListeners();
      }
    }

    // ── 4. Start the session ──────────────────────────────────────────────────
    _pausedDuration = Duration.zero;
    _pauseStartedAt = null;
    _capturedMeasurements.clear();

    final startedAt = DateTime.now();
    _activeCsvPath = await _csvRecordingService.startRecording();
    // Open the sink on the foreground instance so enriched rows can be
    // written here after AI prediction completes.
    _csvRecordingService.openForAppending(_activeCsvPath!);
    debugPrint('[RecordingService] Session created and sink opened: CSV=$_activeCsvPath');

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

    service.invoke('setCsvPath', {'csvPath': _activeCsvPath});
    debugPrint('[RecordingService] Sent setCsvPath=$_activeCsvPath to background service');
  }

  Future<void> pauseRecording() async {
    if (!_state.isRecording || _state.isPaused) return;

    _pauseStartedAt = DateTime.now();
    _state = _state.copyWith(
      isPaused: true,
      elapsedDuration: _elapsedSinceStart(),
    );
    notifyListeners();

    FlutterBackgroundService().invoke('pauseRecording');
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

    FlutterBackgroundService().invoke('resumeRecording');
  }

  Future<void> stopRecording() async {
    if (!_state.isRecording) return;

    if (_pauseStartedAt != null) {
      _pausedDuration += DateTime.now().difference(_pauseStartedAt!);
      _pauseStartedAt = null;
    }

    final service = FlutterBackgroundService();
    final stoppedAck = service.on('recordingServiceStopped').first.timeout(
      const Duration(seconds: 9),
      onTimeout: () => <String, dynamic>{
        'timedOut': true,
      },
    );

    service.invoke('stopService');
    final ack = await stoppedAck;
    final completedPath = ack?['csvPath'] as String?;
    debugPrint('[RecordingService] Session stopped. CSV saved to: $completedPath');

    // Close the foreground CSV sink.
    await _csvRecordingService.stopRecording();

    _activeCsvPath = null;
    final endedAt = DateTime.now();

    _state = _state.copyWith(
      isRecording: false,
      isPaused: false,
      elapsedDuration: _elapsedSinceStart(finalMoment: endedAt),
      clearError: true,
    );
    notifyListeners();
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
}
