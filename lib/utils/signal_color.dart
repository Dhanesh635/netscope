import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Color signalColorForRsrp(double rsrp) {
  if (rsrp > -90) {
    return Colors.green;
  }
  if (rsrp >= -110) {
    return Colors.yellow;
  }
  return Colors.red;
}

Color signalColorForSinr(double? sinr) {
  if (sinr == null) {
    return Colors.grey;
  }
  if (sinr > 20) {
    return Colors.green;
  }
  if (sinr >= 10) {
    return Colors.yellow;
  }
  return Colors.red;
}

Color signalColorForDownload(double download) {
  if (download > 50) {
    return Colors.green;
  }
  if (download >= 10) {
    return Colors.yellow;
  }
  return Colors.red;
}

bool isStrongSignalRsrp(double rsrp) => rsrp > -90;
bool isModerateSignalRsrp(double rsrp) => rsrp >= -110 && rsrp <= -90;
bool isWeakSignalRsrp(double rsrp) => rsrp < -110;

double signalMarkerHueForRsrp(double rsrp) {
  if (isStrongSignalRsrp(rsrp)) {
    return BitmapDescriptor.hueGreen;
  }
  if (isModerateSignalRsrp(rsrp)) {
    return BitmapDescriptor.hueYellow;
  }
  return BitmapDescriptor.hueRed;
}

double signalMarkerHueForColor(Color color) {
  if (color == Colors.green) return BitmapDescriptor.hueGreen;
  if (color == Colors.yellow) return BitmapDescriptor.hueYellow;
  return BitmapDescriptor.hueRed;
}
