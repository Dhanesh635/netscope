import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Lightweight download/upload speed tester.
///
/// Uses Cloudflare's speed-test endpoints which are globally distributed,
/// fast, and do not require an API key.
class SpeedTestService {
  SpeedTestService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Download test payload size in bytes (1 MB — balances accuracy vs time).
  static const int _downloadBytes = 1 * 1024 * 1024;

  /// Upload test payload size in bytes (500 KB).
  static const int _uploadBytes = 500 * 1024;

  static const Map<String, String> _headers = {
    'User-Agent': 'NetScope/1.0 (Mobile SpeedTest)',
  };

  /// Measures download speed in Mbps.
  ///
  /// Downloads [_downloadBytes] bytes from Cloudflare's edge network and
  /// returns throughput in megabits per second.
  /// Returns `null` on any failure.
  Future<double?> measureDownload() async {
    final url = Uri.parse(
      'https://speed.cloudflare.com/__down?bytes=$_downloadBytes',
    );

    try {
      final stopwatch = Stopwatch()..start();
      final response = await _client.get(url, headers: _headers).timeout(
        const Duration(seconds: 20),
      );
      stopwatch.stop();

      if (response.statusCode != 200) {
        debugPrint('[SpeedTest] Download failed: HTTP ${response.statusCode}');
        return null;
      }

      final bytes = response.contentLength ?? response.bodyBytes.length;
      final seconds = stopwatch.elapsedMilliseconds / 1000.0;
      if (seconds <= 0) return null;

      final mbps = (bytes * 8) / (seconds * 1000 * 1000);
      debugPrint(
        '[SpeedTest] Download: ${bytes}B in ${seconds.toStringAsFixed(2)}s '
        '= ${mbps.toStringAsFixed(2)} Mbps',
      );
      return mbps;
    } catch (e) {
      debugPrint('[SpeedTest] Download error: $e');
      return null;
    }
  }

  /// Measures upload speed in Mbps.
  ///
  /// Sends [_uploadBytes] bytes to Cloudflare's upload endpoint and
  /// returns throughput in megabits per second.
  /// Returns `null` on any failure.
  Future<double?> measureUpload() async {
    final url = Uri.parse('https://speed.cloudflare.com/__up');

    try {
      final payload = List<int>.filled(_uploadBytes, 0x41); // 'A' bytes
      final stopwatch = Stopwatch()..start();
      
      final headers = Map<String, String>.from(_headers)
        ..putIfAbsent('Content-Type', () => 'application/octet-stream');

      final response = await _client.post(
        url,
        body: payload,
        headers: headers,
      ).timeout(const Duration(seconds: 20));
      stopwatch.stop();

      if (response.statusCode != 200) {
        debugPrint('[SpeedTest] Upload failed: HTTP ${response.statusCode}');
        return null;
      }

      final seconds = stopwatch.elapsedMilliseconds / 1000.0;
      if (seconds <= 0) return null;

      final mbps = (_uploadBytes * 8) / (seconds * 1000 * 1000);
      debugPrint(
        '[SpeedTest] Upload: ${_uploadBytes}B in ${seconds.toStringAsFixed(2)}s '
        '= ${mbps.toStringAsFixed(2)} Mbps',
      );
      return mbps;
    } catch (e) {
      debugPrint('[SpeedTest] Upload error: $e');
      return null;
    }
  }

  /// Runs both download and upload tests sequentially.
  /// Returns a record of (downloadMbps, uploadMbps).
  /// Either value may be `null` on failure.
  Future<({double? download, double? upload})> runFullTest() async {
    final download = await measureDownload();
    final upload = await measureUpload();
    return (download: download, upload: upload);
  }

  void dispose() {
    _client.close();
  }
}
