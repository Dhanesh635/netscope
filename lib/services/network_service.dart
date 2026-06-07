import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/signal_info.dart';

class NetworkService {
  NetworkService({MethodChannel? channel}) : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'netscope/network';
  final MethodChannel _channel;

  Future<SignalInfo> getCurrentSignalInfo() async {
    debugPrint('[NetworkService] getCurrentSignalInfo() called, platform=$defaultTargetPlatform');

    if (defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('[NetworkService] Not Android — returning unsupported');
      return const SignalInfo(
        status: SignalInfoStatus.unsupported,
        message: 'Cellular signal info is only available on Android.',
      );
    }

    try {
      debugPrint('[NetworkService] Invoking MethodChannel "getCurrentSignalInfo"...');
      final result = await _channel.invokeMapMethod<String, Object?>(
        'getCurrentSignalInfo',
      );
      debugPrint('[NetworkService] Raw MethodChannel result: $result');

      if (result == null) {
        debugPrint('[NetworkService] Result is null — returning unavailable');
        return const SignalInfo(
          status: SignalInfoStatus.unavailable,
          message: 'No cellular signal info was returned.',
        );
      }

      final signalInfo = SignalInfo.fromMap(result);
      debugPrint('[NetworkService] Parsed SignalInfo: '
          'status=${signalInfo.status}, '
          'tech=${signalInfo.technology}, '
          'rsrp=${signalInfo.rsrp}, '
          'rsrq=${signalInfo.rsrq}, '
          'sinr=${signalInfo.sinr}, '
          'pci=${signalInfo.pci}, '
          'carrier=${signalInfo.carrier}, '
          'message=${signalInfo.message}');
      return signalInfo;
    } on PlatformException catch (error) {
      debugPrint('[NetworkService] PlatformException: code=${error.code}, message=${error.message}, details=${error.details}');
      return SignalInfo(
        status: _statusFromPlatformErrorCode(error.code),
        message: error.message ?? error.details?.toString() ?? error.code,
      );
    } on MissingPluginException {
      debugPrint('[NetworkService] MissingPluginException — no native handler registered for this isolate');
      return const SignalInfo(
        status: SignalInfoStatus.unsupported,
        message: 'Native cellular signal service is not registered.',
      );
    } catch (error) {
      debugPrint('[NetworkService] Unexpected error: $error');
      return SignalInfo(
        status: SignalInfoStatus.error,
        message: error.toString(),
      );
    }
  }

  SignalInfoStatus _statusFromPlatformErrorCode(String code) {
    switch (code) {
      case 'permission_denied':
        return SignalInfoStatus.permissionDenied;
      case 'unsupported':
        return SignalInfoStatus.unsupported;
      case 'unavailable':
        return SignalInfoStatus.unavailable;
      case 'error':
      default:
        return SignalInfoStatus.error;
    }
  }
}
