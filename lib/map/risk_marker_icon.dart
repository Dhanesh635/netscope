import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Returns the fill [Color] that corresponds to a backend [riskLevel] string.
Color riskLevelColor(String? riskLevel) {
  switch (riskLevel?.toLowerCase()) {
    case 'low':
      return const Color(0xFF00E676); // green
    case 'medium':
      return const Color(0xFFFFD600); // yellow
    case 'high':
      return const Color(0xFFFF9800); // orange
    case 'critical':
      return const Color(0xFFFF5252); // red
    default:
      return const Color(0xFF00BFFF); // default azure (matches app primary)
  }
}

/// Renders a circular marker bitmap: colored fill + white border + drop shadow.
///
/// The result is cached by risk level so we only paint each variant once per
/// app session.
final Map<String, BitmapDescriptor> _iconCache = {};

Future<BitmapDescriptor> buildRiskMarkerIcon(String? riskLevel) async {
  final key = riskLevel?.toLowerCase() ?? 'default';
  if (_iconCache.containsKey(key)) return _iconCache[key]!;

  final color = riskLevelColor(riskLevel);
  const double size = 18; // logical pixels — keep markers compact on map
  final double devicePixelRatio =
      PlatformDispatcher.instance.views.first.devicePixelRatio;
  final double physicalSize = size * devicePixelRatio;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, physicalSize, physicalSize),
  );

  final center = Offset(physicalSize / 2, physicalSize / 2);
  final radius = physicalSize / 2;

  // ── Drop shadow ──────────────────────────────────────────────────────────
  final shadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.35)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, physicalSize * 0.12);
  canvas.drawCircle(
    center.translate(0, physicalSize * 0.05),
    radius * 0.72,
    shadowPaint,
  );

  // ── White border ─────────────────────────────────────────────────────────
  final borderPaint = Paint()..color = Colors.white;
  canvas.drawCircle(center, radius * 0.78, borderPaint);

  // ── Colored fill ─────────────────────────────────────────────────────────
  final fillPaint = Paint()..color = color;
  canvas.drawCircle(center, radius * 0.62, fillPaint);

  // ── Inner highlight for depth ─────────────────────────────────────────────
  final highlightPaint = Paint()
    ..shader = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      radius: 0.7,
      colors: [
        Colors.white.withValues(alpha: 0.35),
        Colors.transparent,
      ],
    ).createShader(
      Rect.fromCircle(center: center, radius: radius * 0.62),
    );
  canvas.drawCircle(center, radius * 0.62, highlightPaint);

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    physicalSize.round(),
    physicalSize.round(),
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();

  final descriptor = BitmapDescriptor.bytes(bytes, imagePixelRatio: devicePixelRatio);
  _iconCache[key] = descriptor;
  return descriptor;
}

/// Clears the icon cache — call this if device pixel ratio changes (rare).
@visibleForTesting
void clearRiskMarkerIconCache() => _iconCache.clear();
