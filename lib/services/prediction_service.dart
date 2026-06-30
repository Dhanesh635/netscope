import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/network_measurement.dart';
import '../models/prediction_result.dart';

class PredictionService {
  PredictionService._();

  static final PredictionService instance = PredictionService._();

  // Emulator
  // static const String _baseUrl = "http://10.0.2.2:8000";

  static const String _baseUrl = "http://127.0.0.1:8000";
  // Real phone
  // static const String _baseUrl = "http://192.168.1.xxx:8000";

  Future<PredictionResult?> predict(
    
      NetworkMeasurement measurement) async {
    try {
      print("===== AI PREDICTION START =====");
      final response = await http.post(
        Uri.parse("$_baseUrl/predict"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "rsrp": measurement.rsrp,
          "rsrq": measurement.rsrq,
          "sinr": measurement.sinr,
          "download": measurement.download,
          "upload": measurement.upload,
          "velocity": measurement.velocity,
          "latitude": measurement.latitude,
          "longitude": measurement.longitude,
        }),
      );

      print("Status: ${response.statusCode}");
      print("Response: ${response.body}");

      if (response.statusCode != 200) {
        return null;
      }

      return PredictionResult.fromJson(
        jsonDecode(response.body),
      );
} catch (e, st) {
  print("================================");
  print("PREDICTION EXCEPTION");
  print(e);
  print(st);
  print("================================");
  rethrow;
}
  }
}