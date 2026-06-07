import 'dart:async';
import 'dart:ui';

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/database_helper.dart';
import '../data/measurement_repository.dart';
import '../location/location_service.dart';
import '../models/network_measurement.dart';
import '../models/signal_info.dart';

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

    final measurementRepository = MeasurementRepository();
    const locationService = LocationService();

    // Log the database path from the background isolate for cross-isolate comparison
    try {
      final bgDb = await DatabaseHelper.instance.database;
      debugPrint('[BackgroundRecording] DB path (background isolate): ${bgDb.path}');
    } catch (e) {
      debugPrint('[BackgroundRecording] ERROR accessing DB in background: $e');
    }

    int? sessionId;
    Timer? samplingTimer;
    Future<void>? activeSample;

    int recordedCount = 0;
    int savedCount = 0;

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
    // The MethodChannel for 'netscope/network' is only registered on the main
    // FlutterEngine. This background isolate cannot invoke it directly.
    // Instead, we request signal info from the foreground via IPC.
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

    /// Requests signal info from the foreground isolate via IPC.
    /// Falls back to [SignalInfoStatus.unavailable] if the foreground doesn't
    /// respond within 2 seconds (e.g. app killed, screen off).
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
    // Start at 0, not 999. The old value of 999 forced a speed-test IPC on
    // the very first sampleData() call. That 30-second round-trip meant the
    // first measurement was never written until well after the user might have
    // already stopped the recording, producing an empty CSV. Speed tests are
    // still triggered every ~60 s (12 × 5 s cycles) — just not on sample #1.
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

    // ── Service lifecycle ───────────────────────────────────────────────────

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

      debugPrint('[BackgroundRecording] Stop — Recorded: $recordedCount, Saved: $savedCount');
      if (recordedCount != savedCount) {
        debugPrint('[BackgroundRecording] WARNING: Measurement loss detected!');
      }
      service.invoke('recordingServiceStopped', {
        'recordedCount': recordedCount,
        'savedCount': savedCount,
      });
      service.stopSelf();
    });

    // ── Periodic sampling ───────────────────────────────────────────────────

    Future<void> sampleData() async {
      if (sessionId == null) {
        // Fallback: Check DB for the most recent open session
        try {
          final db = await DatabaseHelper.instance.database;
          final rows = await db.query(
            DatabaseHelper.sessionsTable,
            where: 'ended_at IS NULL',
            orderBy: 'id DESC',
            limit: 1,
          );
          if (rows.isNotEmpty) {
            sessionId = rows.first['id'] as int;
            debugPrint('[BackgroundRecording] Recovered sessionId $sessionId from DB');
          }
        } catch (e) {
          debugPrint('[BackgroundRecording] Error recovering sessionId: $e');
        }

        if (sessionId == null) {
          service.invoke('requestSessionId');
          return;
        }
      }

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
          // Do not await the speed test, let it update cached values when done.
          requestSpeedTestFromForeground().then((speed) {
            if (speed.download != null) cachedDownload = speed.download!;
            if (speed.upload != null) cachedUpload = speed.upload!;
          });
        }

        recordedCount++;

        final sample = NetworkMeasurement(
          sessionId: sessionId,
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
          await measurementRepository.insertMeasurement(sample);
          savedCount++;
          debugPrint('[BackgroundRecording] Sample #$recordedCount saved successfully');
        } catch (e, st) {
          debugPrint('[BackgroundRecording] DB INSERT ERROR: $e\n$st');
          try {
            final dir = await getApplicationDocumentsDirectory();
            final file = File('${dir.path}/db_errors.txt');
            await file.writeAsString('Error inserting sample $recordedCount: $e\n', mode: FileMode.append);
          } catch (_) {}
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
        service.invoke('onMeasurementCaptured', sample.toMap());
      } on Exception catch (e) {
        // Location errors or unexpected failures: log and skip this sample.
        // We never let an exception kill the background isolate.
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

    service.on('setSessionId').listen((event) {
      final newId = event?['sessionId'] as int?;
      if (newId != null && sessionId == null) {
        sessionId = newId;
        // Trigger first sample immediately when session is known
        runSample();
      } else {
        sessionId = newId;
      }
    });

    samplingTimer = Timer.periodic(const Duration(seconds: 5), (_) => runSample());

  }

  /// Extracts signal metric values from [SignalInfo], returning safe fallback
  /// defaults when the info is unavailable or permission is denied.
  static (double, double, double, int, String, String) _extractSignalValues(
    SignalInfo signalInfo,
  ) {
    if (signalInfo.status == SignalInfoStatus.available) {
      return (
        signalInfo.rsrp?.toDouble() ?? -140.0,
        signalInfo.rsrq?.toDouble() ?? -20.0,
        signalInfo.sinr ?? -10.0,
        signalInfo.pci ?? 0,
        signalInfo.carrier ?? 'NO_SERVICE',
        signalInfo.technology.displayName,
      );
    }

    // Fallback for permission denied, unsupported, unavailable, or error.
    return (
      -140.0, // rsrp — below detectable range, clearly a sentinel
      -20.0,  // rsrq
      -10.0,  // sinr
      0,      // pci
      'NO_SERVICE',
      'NONE',
    );
  }
}
