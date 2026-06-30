import 'dart:async';
import 'dart:ui';

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../services/csv_recording_service.dart';
import '../location/location_service.dart';
import '../models/network_measurement.dart';
import '../models/signal_info.dart';
import '../services/prediction_service.dart';

@pragma('vm:entry-point')
class BackgroundRecordingService {
  static const String _notificationChannelId = 'recording_service';
  static const int _notificationId = 888;

  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _notificationChannelId,
      'Recording Service',
      description: 'Maintains recording in background',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _notificationChannelId,
        initialNotificationTitle: 'NetScope Recording',
        initialNotificationContent: 'Initializing...',
        foregroundServiceNotificationId: _notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    final locationService = LocationService();
    final csvRecordingService = CsvRecordingService();

    String? activeCsvPath;
    Timer? samplingTimer;
    Future<void>? activeSample;

    int recordedCount = 0;
    int savedCount = 0;
    bool isPaused = false;

    String deviceId = '';
    String deviceMake = '';
    String deviceModel = '';
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        deviceMake = androidInfo.manufacturer;
        deviceModel = androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? '';
        deviceMake = 'Apple';
        deviceModel = iosInfo.name;
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }

    // ── Signal IPC: request signal data from the foreground isolate ─────────
    Completer<SignalInfo>? signalCompleter;

    service.on('signalInfoResponse').listen((event) {
      if (event != null &&
          signalCompleter != null &&
          !signalCompleter!.isCompleted) {
        try {
          signalCompleter!.complete(
            SignalInfo.fromMap(Map<String, Object?>.from(event)),
          );
        } catch (e) {
          debugPrint('BackgroundRecordingService: error parsing signal response — $e');
          if (!signalCompleter!.isCompleted) {
            signalCompleter!.complete(
              const SignalInfo(status: SignalInfoStatus.unavailable),
            );
          }
        }
      }
    });

    Future<SignalInfo> requestSignalFromForeground() async {
      signalCompleter = Completer<SignalInfo>();
      service.invoke('requestSignalInfo');
      try {
        return await signalCompleter!.future
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        return const SignalInfo(
          status: SignalInfoStatus.unavailable,
          message: 'Foreground signal request timed out',
        );
      }
    }

    // ── Speed test IPC ──────────────────────────────────────────────────────
    Completer<({double? download, double? upload})>? speedCompleter;
    double cachedDownload = 0;
    double cachedUpload = 0;
    int samplesSinceSpeedTest = 0;

    service.on('speedTestResponse').listen((event) {
      if (event != null &&
          speedCompleter != null &&
          !speedCompleter!.isCompleted) {
        try {
          speedCompleter!.complete((
            download: (event['download'] as num?)?.toDouble(),
            upload: (event['upload'] as num?)?.toDouble(),
          ));
        } catch (e) {
          if (!speedCompleter!.isCompleted) {
            speedCompleter!.complete((download: null, upload: null));
          }
        }
      }
    });

    Future<({double? download, double? upload})> requestSpeedTestFromForeground() async {
      speedCompleter = Completer();
      service.invoke('requestSpeedTest');
      try {
        return await speedCompleter!.future
            .timeout(const Duration(seconds: 30));
      } catch (_) {
        return (download: null, upload: null);
      }
    }

    // ── Periodic sampling functions ──────────────────────────────────────────

    Future<void> sampleData() async {
      if (isPaused) return;

      try {
        double lat = 0.0;
        double lng = 0.0;
        double velocity = 0.0;

        try {
          final position = await locationService.getCurrentLocation().timeout(const Duration(seconds: 3));
          lat = position.latitude;
          lng = position.longitude;
          velocity = locationService.velocityFrom(position) ?? 0.0;
        } catch (e) {
          debugPrint('Location fetch failed: $e');
        }

        // Request signal info from the foreground isolate (where MethodChannel works).
        final signalInfo = await requestSignalFromForeground();

        // Build fallback values when signal info is unavailable.
        final (rsrp, rsrq, sinr, pci, carrier, networkType) =
            _extractSignalValues(signalInfo);

        // Run speed test on first sample and every ~60 seconds (12 × 5s).
        samplesSinceSpeedTest++;
        if (samplesSinceSpeedTest >= 12) {
          samplesSinceSpeedTest = 0;
          requestSpeedTestFromForeground().then((speed) {
            if (speed.download != null) cachedDownload = speed.download!;
            if (speed.upload != null) cachedUpload = speed.upload!;
          });
        }

        recordedCount++;

        final sample = NetworkMeasurement(
          sessionId: 0,
          deviceId: deviceId,
          deviceMake: deviceMake,
          deviceModel: deviceModel,
          timestamp: DateTime.now(),
          latitude: lat,
          longitude: lng,
          rsrp: rsrp,
          rsrq: rsrq,
          sinr: sinr,
          download: cachedDownload,
          upload: cachedUpload,
          pci: pci,
          carrier: carrier,
          networkType: networkType,
          velocity: velocity,
        );




        debugPrint('[BackgroundRecording] Sample #$recordedCount: '
            'time=${sample.timestamp.toIso8601String()}, '
            'lat=${sample.latitude.toStringAsFixed(6)}, '
            'lng=${sample.longitude.toStringAsFixed(6)}, '
            'RSRP=${sample.rsrp.toStringAsFixed(0)}, '
            'PCI=${sample.pci}');

        try {
          if (activeCsvPath != null) {
            await csvRecordingService.appendMeasurement(sample);
            savedCount++;
            debugPrint('[BackgroundRecording] Sample #$recordedCount generated and written');
          }
        } catch (e, st) {
          debugPrint('[BackgroundRecording] CSV APPEND ERROR: $e\n$st');
        }

        final notifBody = signalInfo.status == SignalInfoStatus.permissionDenied
            ? 'Signal permission denied — location only'
            : signalInfo.status != SignalInfoStatus.available
                ? 'Signal unavailable — location at ${lat.toStringAsFixed(4)}'
                : 'Captured ${sample.networkType} at ${sample.rsrp.toStringAsFixed(0)} dBm';

        flutterLocalNotificationsPlugin.show(
          _notificationId,
          'NetScope Recording',
          notifBody,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _notificationChannelId,
              'Recording Service',
              ongoing: true,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );

        // Notify UI if alive — always invoked, even for fallback measurements.
        service.invoke(
  'onMeasurementCaptured',
  sample.toMap(),
);
      } on Exception catch (e) {
        debugPrint('BackgroundRecordingService: sample error — $e');
      }
    }

    Future<void> runSample() {
      if (activeSample != null) {
        return activeSample!;
      }

      activeSample = sampleData().whenComplete(() {
        activeSample = null;
      });
      return activeSample!;
    }

    // ── Service lifecycle listeners ──────────────────────────────────────────

    service.on('stopService').listen((event) async {
      samplingTimer?.cancel();
      final pendingSample = activeSample;
      if (pendingSample != null) {
        try {
          await pendingSample.timeout(const Duration(seconds: 8));
        } catch (e) {
          debugPrint('[BackgroundRecording] Timed out waiting for active sample: $e');
        }
      }

      final completedPath = await csvRecordingService.stopRecording();

      debugPrint('[BackgroundRecording] Stop — Recorded: $recordedCount, Saved: $savedCount');
      if (recordedCount != savedCount) {
        debugPrint('[BackgroundRecording] WARNING: Measurement loss detected!');
      }
      service.invoke('recordingServiceStopped', {
        'recordedCount': recordedCount,
        'savedCount': savedCount,
        'csvPath': completedPath,
      });
      service.stopSelf();
    });

    // Pause / Resume event listeners
    service.on('pauseRecording').listen((_) {
      isPaused = true;
      debugPrint('[BackgroundRecording] Paused recording');
    });

    service.on('resumeRecording').listen((_) {
      isPaused = false;
      debugPrint('[BackgroundRecording] Resumed recording');
    });

    service.on('setCsvPath').listen((event) {
      final newPath = event?['csvPath'] as String?;
      if (newPath != null && activeCsvPath == null) {
        activeCsvPath = newPath;
        csvRecordingService.openForAppending(newPath);
        // Trigger first sample immediately when CSV path is known
        runSample();
      } else {
        activeCsvPath = newPath;
      }
    });

    samplingTimer = Timer.periodic(const Duration(seconds: 5), (_) => runSample());
  }

  /// Extracts signal metric values from [SignalInfo], returning safe fallback
  /// defaults when the info is unavailable or permission is denied.
  static (double, double, double?, int, String, String) _extractSignalValues(
    SignalInfo signalInfo,
  ) {
    if (signalInfo.status == SignalInfoStatus.available) {
      return (
        signalInfo.rsrp?.toDouble() ?? -140.0,
        signalInfo.rsrq?.toDouble() ?? -20.0,
        signalInfo.sinr,
        signalInfo.pci ?? 0,
        signalInfo.carrier ?? 'NO_SERVICE',
        signalInfo.technology.displayName,
      );
    }

    // Fallback for permission denied, unsupported, unavailable, or error.
    return (
      -140.0, // rsrp
      -20.0,  // rsrq
      null,   // sinr
      0,      // pci
      'NO_SERVICE',
      'NONE',
    );
  }
}
