import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/network_measurement.dart';

class CsvRecordingService {
  File? _activeFile;
  IOSink? _sink;

  static const String _header =
    'timestamp,deviceid,devicemake,deviceModel,carrier,networktype,RSRP,RSRQ,SINR,PCI,download,upload,velocity,latitude,longitude,handover_probability,prediction,risk_level,qos_score';

  /// Generates a new CSV file in the documents directory with a timestamped name.
  /// Writes the header row immediately, closes the file, and returns the absolute file path.
  Future<String> startRecording() async {
    final directory = await getApplicationDocumentsDirectory();
    
    final now = DateTime.now();
    final filename =
        'drive_test_${now.year}_${_pad(now.month)}_${_pad(now.day)}_${_pad(now.hour)}_${_pad(now.minute)}_${_pad(now.second)}.csv';
    
    final file = File('${directory.path}${Platform.pathSeparator}$filename');
    _activeFile = file;
    _sink = file.openWrite(mode: FileMode.write);
    _sink!.write('$_header\n');
    await _sink!.flush();
    await _sink!.close();
    _sink = null;
    
    debugPrint('[CsvRecordingService] Created CSV with header: ${file.path}');
    return file.path;
  }

  /// Opens an existing CSV file for appending (designed for use in background isolates).
  void openForAppending(String filePath) {
    _activeFile = File(filePath);
    _sink = _activeFile!.openWrite(mode: FileMode.append);
    debugPrint('[CsvRecordingService] Opened CSV for appending: $filePath');
  }

  /// Appends a [NetworkMeasurement] to the active CSV file.
  Future<void> appendMeasurement(NetworkMeasurement measurement) async {
    final sink = _sink;
    if (sink == null) {
      throw StateError('No active recording session (sink is null)');
    }

    final row = [
      measurement.timestamp.toIso8601String(),
      _escapeCsv(measurement.deviceId),
      _escapeCsv(measurement.deviceMake),
      _escapeCsv(measurement.deviceModel),
      _escapeCsv(measurement.carrier),
      _escapeCsv(measurement.networkType),
      measurement.rsrp.toStringAsFixed(1),
      measurement.rsrq.toStringAsFixed(1),
      measurement.sinr != null ? measurement.sinr!.toStringAsFixed(1) : 'NULL',
      measurement.pci.toString(),
      measurement.download.toStringAsFixed(2),
      measurement.upload.toStringAsFixed(2),
      measurement.velocity.toStringAsFixed(2),
      measurement.latitude.toStringAsFixed(6),
      measurement.longitude.toStringAsFixed(6),
      measurement.handoverProbability?.toStringAsFixed(4) ?? '',
      measurement.prediction ?? '',
      measurement.riskLevel ?? '',
      measurement.qosScore?.toStringAsFixed(4) ?? '',
    ].join(',');

    sink.write('$row\n');
    await sink.flush();
    debugPrint('[CsvRecordingService] Appended row to ${_activeFile?.path}');
  }

  /// Flushes pending writes and closes the active CSV file.
  Future<String?> stopRecording() async {
    final sink = _sink;
    if (sink == null) return _activeFile?.path;
    final path = _activeFile?.path;
    await sink.flush();
    await sink.close();
    _sink = null;
    _activeFile = null;
    debugPrint('[CsvRecordingService] Closed CSV: $path');
    return path;
  }

  /// Retrieves all drive test CSV files from the documents directory.
  static Future<List<File>> getCsvFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final entities = directory.listSync();
      
      final csvFiles = entities
          .whereType<File>()
          .where((f) => f.path.endsWith('.csv') && f.path.contains('drive_test_'))
          .toList();
          
      // Sort newest first based on file modified time
      csvFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return csvFiles;
    } catch (e) {
      debugPrint('[CsvRecordingService] Error listing CSV files: $e');
      return [];
    }
  }

  /// Deletes the specified CSV file.
  static Future<void> deleteCsvFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[CsvRecordingService] Deleted $filePath');
      }
    } catch (e) {
      debugPrint('[CsvRecordingService] Error deleting CSV file: $e');
    }
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');

  /// Ensures strings with commas or quotes are properly escaped for CSV.
  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }
}
