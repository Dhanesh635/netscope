import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:netscope/utils/signal_color.dart';

void main() {
  test('maps RSRP to the expected color bucket', () {
    expect(signalColorForRsrp(-85), Colors.green);
    expect(signalColorForRsrp(-90), Colors.yellow);
    expect(signalColorForRsrp(-110), Colors.yellow);
    expect(signalColorForRsrp(-111), Colors.red);
  });

  test('maps RSRP to the expected marker hue bucket', () {
    expect(signalMarkerHueForRsrp(-80), BitmapDescriptor.hueGreen);
    expect(signalMarkerHueForRsrp(-100), BitmapDescriptor.hueYellow);
    expect(signalMarkerHueForRsrp(-120), BitmapDescriptor.hueRed);
  });
}
