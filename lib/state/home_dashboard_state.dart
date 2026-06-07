import 'dart:async';

import 'package:flutter/foundation.dart';

import '../location/location_provider.dart';
import '../models/network_measurement.dart';
import '../models/signal_info.dart';
import '../recording/recording_service.dart';
import '../recording/recording_state.dart';
import '../services/network_service.dart';
import '../services/speed_test_service.dart';

class HomeDashboardState extends ChangeNotifier {
  final NetworkService _networkService = NetworkService();
  final SpeedTestService _speedTestService = SpeedTestService();
  Timer? _signalPollTimer;
  SignalInfo? _liveSignalInfo;
  double? _liveDownload;
  double? _liveUpload;
  bool _speedTestRunning = false;
  bool _initialSpeedTestDone = false;

  RecordingService? _recordingService;
  LocationProvider? _locationProvider;
  NetworkMeasurement? _latestMeasurement;

  bool get isRecording => _recordingService?.state.isRecording ?? false;
  bool get isPaused => _recordingService?.state.isPaused ?? false;
  bool get hasLiveMeasurement => _latestMeasurement != null;

  /// The most recent recording error from the recording service.
  RecordingError? get lastRecordingError =>
      _recordingService?.state.lastError;

  // ── Signal labels (prefer live polling data, fall back to recording) ──────

  String get rsrpLabel {
    if (_liveSignalInfo?.rsrp != null) {
      return _formatSigned(_liveSignalInfo!.rsrp!.toDouble());
    }
    if (_latestMeasurement != null) return _formatSigned(_latestMeasurement!.rsrp);
    return '—';
  }

  String get rsrqLabel {
    if (_liveSignalInfo?.rsrq != null) {
      return _formatSigned(_liveSignalInfo!.rsrq!.toDouble());
    }
    if (_latestMeasurement != null) return _formatSigned(_latestMeasurement!.rsrq);
    return '—';
  }

  String get sinrLabel {
    if (_liveSignalInfo?.sinr != null) {
      return _formatDecimal(_liveSignalInfo!.sinr);
    }
    if (_latestMeasurement != null) return _formatDecimal(_latestMeasurement!.sinr);
    return '—';
  }

  String get pciLabel {
    if (_liveSignalInfo?.pci != null) {
      return _formatInt(_liveSignalInfo!.pci);
    }
    if (_latestMeasurement != null) return _formatInt(_latestMeasurement!.pci);
    return '—';
  }

  String get carrierLabel {
    if (_liveSignalInfo?.carrier != null) return _liveSignalInfo!.carrier!;
    if (_latestMeasurement != null) return _latestMeasurement!.carrier;
    return '—';
  }

  String get networkTypeLabel {
    if (_liveSignalInfo?.status == SignalInfoStatus.available) {
      return _liveSignalInfo!.technology.displayName;
    }
    if (_latestMeasurement != null) return _latestMeasurement!.networkType;
    return '—';
  }

  String get downloadLabel {
    if (_liveDownload != null) return _formatDecimal(_liveDownload);
    if (_latestMeasurement != null && _latestMeasurement!.download > 0) {
      return _formatDecimal(_latestMeasurement!.download);
    }
    if (_speedTestRunning) return '...';
    return '—';
  }

  String get uploadLabel {
    if (_liveUpload != null) return _formatDecimal(_liveUpload);
    if (_latestMeasurement != null && _latestMeasurement!.upload > 0) {
      return _formatDecimal(_latestMeasurement!.upload);
    }
    if (_speedTestRunning) return '...';
    return '—';
  }

  String get velocityLabel {
    final velocityMetersPerSecond =
        _locationProvider?.velocity ?? _latestMeasurement?.velocity;

    if (velocityMetersPerSecond == null) {
      return '—';
    }

    return _formatDecimal(velocityMetersPerSecond * 3.6);
  }

  String get liveStatusLabel {
    if (isRecording && isPaused) {
      return 'Recording paused';
    }

    if (isRecording) {
      return 'Recording live data';
    }

    if (_liveSignalInfo != null &&
        _liveSignalInfo!.status == SignalInfoStatus.available) {
      return 'Live ${_liveSignalInfo!.technology.displayName} signal';
    }

    if (hasLiveMeasurement) {
      return 'Latest captured session data';
    }

    return 'Ready to start drive test';
  }

  String get startButtonLabel {
    if (isRecording) {
      return isPaused ? 'Resume Drive Test' : 'Recording Active';
    }

    return 'START DRIVE TEST';
  }

  void attachSources(
    LocationProvider locationProvider,
    RecordingService recordingService,
  ) {
    if (identical(_locationProvider, locationProvider) &&
        identical(_recordingService, recordingService)) {
      _syncFromSources(notify: false);
      return;
    }

    _locationProvider?.removeListener(_syncFromSources);
    _recordingService?.removeListener(_syncFromSources);

    _locationProvider = locationProvider;
    _recordingService = recordingService;

    _locationProvider?.addListener(_syncFromSources);
    _recordingService?.addListener(_syncFromSources);
    _syncFromSources(notify: false);

    _startSignalPolling();
  }

  Future<void> startRecording() async {
    await _recordingService?.startRecording();
  }

  Future<void> pauseRecording() async {
    await _recordingService?.pauseRecording();
  }

  Future<void> resumeRecording() async {
    await _recordingService?.resumeRecording();
  }

  Future<void> stopRecording() async {
    await _recordingService?.stopRecording();
  }

  /// Polls [NetworkService] from the foreground isolate every 3 seconds.
  /// The MethodChannel handler is registered on the main FlutterEngine, so
  /// this call always succeeds in the foreground.
  void _startSignalPolling() {
    if (_signalPollTimer != null) return; // Already polling
    _signalPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final info = await _networkService.getCurrentSignalInfo();
        _liveSignalInfo = info;
        notifyListeners();

        // Trigger a one-time speed test once we have signal.
        if (!_initialSpeedTestDone &&
            !_speedTestRunning &&
            info.status == SignalInfoStatus.available) {
          runSpeedTest();
        }
      } catch (e) {
        debugPrint('[HomeDashboardState] Signal poll error: $e');
      }
    });
    // Fire an immediate first poll so we don't wait 3 seconds on startup.
    _networkService.getCurrentSignalInfo().then((info) {
      _liveSignalInfo = info;
      notifyListeners();
    }).catchError((e) {
      debugPrint('[HomeDashboardState] Initial signal poll error: $e');
    });
  }

  /// Runs a download + upload speed test in the background.
  Future<void> runSpeedTest() async {
    if (_speedTestRunning) return;
    _speedTestRunning = true;
    _initialSpeedTestDone = true;
    notifyListeners();

    try {
      final result = await _speedTestService.runFullTest();
      _liveDownload = result.download;
      _liveUpload = result.upload;
    } catch (e) {
      debugPrint('[HomeDashboardState] Speed test error: $e');
    } finally {
      _speedTestRunning = false;
      notifyListeners();
    }
  }

  void _syncFromSources({bool notify = true}) {
    _latestMeasurement = _recordingService?.latestMeasurement;
    if (notify) {
      notifyListeners();
    }
  }

  String _formatSigned(double? value) {
    if (value == null) return '—';
    return value.toStringAsFixed(0);
  }

  String _formatInt(int? value) {
    if (value == null) return '—';
    return value.toString();
  }

  String _formatDecimal(double? value) {
    if (value == null) return '—';
    return value.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _signalPollTimer?.cancel();
    _speedTestService.dispose();
    _locationProvider?.removeListener(_syncFromSources);
    _recordingService?.removeListener(_syncFromSources);
    super.dispose();
  }
}
