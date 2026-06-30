import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/network_measurement.dart';
import '../recording/recording_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Compact session summary panel. Reads directly from [RecordingService].
/// Safe to render when not recording — shows an idle placeholder.
/// Fully reusable: drop anywhere that has [RecordingService] in the tree.
class SessionSummaryCard extends StatelessWidget {
  const SessionSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<RecordingService>();
    final state = svc.state;
    final latest = svc.latestMeasurement;
    final previous = svc.previousMeasurement;
    final measurements = svc.capturedMeasurements;

    if (!state.isRecording && measurements.isEmpty) {
      return const _IdlePlaceholder();
    }

    return _SummaryShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryHeader(state: state),
          const SizedBox(height: 16),
          _SessionMetaRow(state: state, csvPath: svc.activeCsvPath),
          const SizedBox(height: 16),
          const _Divider(),
          const SizedBox(height: 14),
          _NetworkSection(latest: latest),
          const SizedBox(height: 14),
          const _Divider(),
          const SizedBox(height: 14),
          _AiBanner(latest: latest),
          const SizedBox(height: 14),
          _TrendSection(measurements: measurements, previous: previous, latest: latest),
          const SizedBox(height: 14),
          const _Divider(),
          const SizedBox(height: 14),
          _SessionFooter(state: state, csvPath: svc.activeCsvPath),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Idle placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _IdlePlaceholder extends StatelessWidget {
  const _IdlePlaceholder();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _SummaryShell(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.summarize_outlined, color: cs.onSurfaceVariant, size: 24),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Session summary will appear once recording starts.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Outer shell
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryShell extends StatelessWidget {
  const _SummaryShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.22)),
      ),
      child: child,
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.10),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Header: title + sample count pill + recording indicator
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.state});
  final dynamic state; // RecordingState

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isRecording = state.isRecording as bool;
    final isPaused = state.isPaused as bool;
    final sampleCount = state.sampleCount as int;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.summarize_outlined, color: cs.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'Session Summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.1,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 8),
        // Sample count pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
          ),
          child: Text(
            '$sampleCount',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Live / Paused dot
        _StatusDot(isRecording: isRecording, isPaused: isPaused),
      ],
    );
  }
}

class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.isRecording, required this.isPaused});
  final bool isRecording;
  final bool isPaused;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isRecording) return const SizedBox.shrink();
    final color =
        widget.isPaused ? const Color(0xFFFFD600) : const Color(0xFFFF5252);
    final label = widget.isPaused ? 'PAUSED' : 'REC';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context2, child2) => Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.5 + 0.5 * _pulse.value),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session meta: duration + elapsed
// ─────────────────────────────────────────────────────────────────────────────

class _SessionMetaRow extends StatelessWidget {
  const _SessionMetaRow({required this.state, required this.csvPath});
  final dynamic state;
  final String? csvPath;

  @override
  Widget build(BuildContext context) {
    final startTime = state.startTime as DateTime?;
    final elapsed = state.elapsedDuration as Duration;

    return Row(
      children: [
        Expanded(
          child: _SmallStat(
            icon: Icons.timer_outlined,
            label: 'Elapsed',
            value: _formatDuration(elapsed),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SmallStat(
            icon: Icons.schedule_outlined,
            label: 'Started',
            value: startTime != null ? _formatTime(startTime) : '—',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SmallStat(
            icon: Icons.update,
            label: 'Interval',
            value: '5 s',
          ),
        ),
      ],
    );
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Network section: carrier, type, RSRP, RSRQ, SINR
// ─────────────────────────────────────────────────────────────────────────────

class _NetworkSection extends StatelessWidget {
  const _NetworkSection({required this.latest});
  final NetworkMeasurement? latest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubsectionLabel(icon: Icons.cell_tower_outlined, label: 'Current Network'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatChip(label: 'Carrier', value: latest?.carrier ?? '—'),
            _StatChip(label: 'Type', value: latest?.networkType ?? '—'),
            _StatChip(
              label: 'RSRP',
              value: latest != null
                  ? '${latest!.rsrp.toStringAsFixed(0)} dBm'
                  : '—',
            ),
            _StatChip(
              label: 'RSRQ',
              value: latest != null
                  ? '${latest!.rsrq.toStringAsFixed(0)} dB'
                  : '—',
            ),
            _StatChip(
              label: 'SINR',
              value: latest?.sinr != null
                  ? '${latest!.sinr!.toStringAsFixed(1)} dB'
                  : 'N/A',
            ),
            _StatChip(
              label: 'QoS Score',
              value: latest?.qosScore != null
                  ? latest!.qosScore!.toStringAsFixed(3)
                  : '—',
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI status banner
// ─────────────────────────────────────────────────────────────────────────────

class _AiBanner extends StatefulWidget {
  const _AiBanner({required this.latest});
  final NetworkMeasurement? latest;

  @override
  State<_AiBanner> createState() => _AiBannerState();
}

class _AiBannerState extends State<_AiBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 1.0,
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(_AiBanner old) {
    super.didUpdateWidget(old);
    if (widget.latest?.riskLevel != old.latest?.riskLevel) {
      _anim.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final risk = widget.latest?.riskLevel?.toLowerCase();
    final prob = widget.latest?.handoverProbability;

    final (color, icon, headline) = _bannerConfig(risk);

    final prediction = widget.latest?.prediction ?? '—';
    final probLabel = prob != null ? '${(prob * 100).toStringAsFixed(1)} %' : '—';

    return FadeTransition(
      opacity: _fade,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SubsectionLabel(icon: Icons.psychology_outlined, label: 'AI Prediction'),
          const SizedBox(height: 10),
          // Status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.40), width: 1.5),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        prediction,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      probLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'probability',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static (Color, IconData, String) _bannerConfig(String? risk) {
    switch (risk) {
      case 'low':
        return (const Color(0xFF00E676), Icons.check_circle_outline, '🟢 Stable Network');
      case 'medium':
        return (const Color(0xFFFFD600), Icons.warning_amber_outlined, '🟡 Moderate Risk');
      case 'high':
        return (const Color(0xFFFF9800), Icons.error_outline, '🟠 High Handover Risk');
      case 'critical':
        return (const Color(0xFFFF5252), Icons.crisis_alert_outlined, '🔴 Immediate Handover Likely');
      default:
        return (const Color(0xFF00BFFF), Icons.psychology_outlined, 'Waiting for prediction…');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trend section: prev vs current + sparkline
// ─────────────────────────────────────────────────────────────────────────────

class _TrendSection extends StatelessWidget {
  const _TrendSection({
    required this.measurements,
    required this.previous,
    required this.latest,
  });

  final List<NetworkMeasurement> measurements;
  final NetworkMeasurement? previous;
  final NetworkMeasurement? latest;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Last ≤10 handover probability values (non-null only)
    final points = measurements
        .map((m) => m.handoverProbability)
        .whereType<double>()
        .toList();
    final sparkPoints =
        points.length > 10 ? points.sublist(points.length - 10) : points;

    final prevProb = previous?.handoverProbability;
    final currProb = latest?.handoverProbability;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubsectionLabel(
          icon: Icons.show_chart_outlined,
          label: 'Handover Probability Trend',
        ),
        const SizedBox(height: 10),
        // Prev vs Current comparison row
        Row(
          children: [
            Expanded(child: _ProbDelta(prev: prevProb, curr: currProb)),
            const SizedBox(width: 12),
            // Sparkline occupies the right 60%
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 52,
                child: sparkPoints.length >= 2
                    ? _AnimatedSparkline(points: sparkPoints)
                    : Center(
                        child: Text(
                          'Collecting data…',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Prev → Current probability delta ──────────────────────────────────────

class _ProbDelta extends StatelessWidget {
  const _ProbDelta({required this.prev, required this.curr});
  final double? prev;
  final double? curr;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final prevLabel =
        prev != null ? '${(prev! * 100).toStringAsFixed(1)} %' : '—';
    final currLabel =
        curr != null ? '${(curr! * 100).toStringAsFixed(1)} %' : '—';

    // Direction
    final (dirIcon, dirColor, dirLabel) = _direction(prev, curr);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(dirIcon, size: 14, color: dirColor),
              const SizedBox(width: 4),
              Text(
                dirLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: dirColor,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            prevLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            currLabel,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          Text(
            'prev → current',
            style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  static (IconData, Color, String) _direction(double? prev, double? curr) {
    if (prev == null || curr == null) {
      return (Icons.remove, Colors.grey, 'Stable');
    }
    final delta = curr - prev;
    if (delta > 0.01) {
      return (Icons.arrow_upward_rounded, const Color(0xFFFF5252), 'Increasing');
    }
    if (delta < -0.01) {
      return (Icons.arrow_downward_rounded, const Color(0xFF00E676), 'Decreasing');
    }
    return (Icons.remove_rounded, const Color(0xFFFFD600), 'Stable');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated sparkline — pure CustomPainter, no external libs
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedSparkline extends StatefulWidget {
  const _AnimatedSparkline({required this.points});
  final List<double> points;

  @override
  State<_AnimatedSparkline> createState() => _AnimatedSparklineState();
}

class _AnimatedSparklineState extends State<_AnimatedSparkline>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progress;
  List<double> _oldPoints = [];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _oldPoints = widget.points;
    _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_AnimatedSparkline old) {
    super.didUpdateWidget(old);
    if (widget.points.length != old.points.length ||
        (widget.points.isNotEmpty &&
            widget.points.last != old.points.last)) {
      _oldPoints = old.points;
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _progress,
      builder: (context2, child2) => CustomPaint(
        painter: _SparklinePainter(
          oldPoints: _oldPoints,
          newPoints: widget.points,
          progress: _progress.value,
          lineColor: cs.primary,
          fillColor: cs.primary.withValues(alpha: 0.12),
          dotColor: cs.primary,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.oldPoints,
    required this.newPoints,
    required this.progress,
    required this.lineColor,
    required this.fillColor,
    required this.dotColor,
  });

  final List<double> oldPoints;
  final List<double> newPoints;
  final double progress;
  final Color lineColor;
  final Color fillColor;
  final Color dotColor;

  /// Lerp between old and new point lists, matching to the longer list length.
  List<double> get _interpolated {
    if (oldPoints.isEmpty) return newPoints;
    if (newPoints.isEmpty) return oldPoints;

    final len = math.max(oldPoints.length, newPoints.length);
    return List.generate(len, (i) {
      final o = i < oldPoints.length ? oldPoints[i] : oldPoints.last;
      final n = i < newPoints.length ? newPoints[i] : newPoints.last;
      return o + (n - o) * progress;
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pts = _interpolated;
    if (pts.length < 2) return;

    final minY = pts.reduce(math.min);
    final maxY = pts.reduce(math.max);
    final rangeY = (maxY - minY).abs();
    final effectiveRange = rangeY < 0.01 ? 0.1 : rangeY;

    // Map a value to canvas coordinates.
    Offset toOffset(int index, double value) {
      final x = size.width * index / (pts.length - 1);
      final y = size.height -
          ((value - minY) / effectiveRange) * (size.height * 0.80) -
          size.height * 0.08;
      return Offset(x, y);
    }

    final offsets = [for (var i = 0; i < pts.length; i++) toOffset(i, pts[i])];

    // ── Filled area ──────────────────────────────────────────────────────
    final fillPath = Path()..moveTo(offsets.first.dx, size.height);
    for (final o in offsets) {
      fillPath.lineTo(o.dx, o.dy);
    }
    fillPath
      ..lineTo(offsets.last.dx, size.height)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = fillColor);

    // ── Line ─────────────────────────────────────────────────────────────
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      // Smooth cubic bezier between consecutive points.
      final prev = offsets[i - 1];
      final curr = offsets[i];
      final cpX = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
    }
    canvas.drawPath(linePath, linePaint);

    // ── Latest dot ───────────────────────────────────────────────────────
    final lastOffset = offsets.last;
    canvas.drawCircle(
      lastOffset,
      4,
      Paint()..color = dotColor,
    );
    canvas.drawCircle(
      lastOffset,
      4,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.progress != progress ||
      old.newPoints.length != newPoints.length ||
      (newPoints.isNotEmpty &&
          old.newPoints.isNotEmpty &&
          newPoints.last != old.newPoints.last);
}

// ─────────────────────────────────────────────────────────────────────────────
// Session footer: started time, elapsed, CSV filename, interval
// ─────────────────────────────────────────────────────────────────────────────

class _SessionFooter extends StatelessWidget {
  const _SessionFooter({required this.state, required this.csvPath});
  final dynamic state;
  final String? csvPath;

  @override
  Widget build(BuildContext context) {
    final startTime = state.startTime as DateTime?;
    final elapsed = state.elapsedDuration as Duration;

    final csvName = csvPath != null
        ? csvPath!.split(RegExp(r'[/\\]')).last
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubsectionLabel(icon: Icons.info_outline, label: 'Session Info'),
        const SizedBox(height: 10),
        _FooterRow(
          icon: Icons.play_circle_outline,
          label: 'Recording started',
          value: startTime != null ? _formatDateTime(startTime) : '—',
        ),
        const SizedBox(height: 6),
        _FooterRow(
          icon: Icons.timer_outlined,
          label: 'Elapsed time',
          value: _formatDuration(elapsed),
        ),
        const SizedBox(height: 6),
        _FooterRow(
          icon: Icons.file_present_outlined,
          label: 'CSV file',
          value: csvName,
          valueMaxLines: 2,
        ),
        const SizedBox(height: 6),
        _FooterRow(
          icon: Icons.repeat_outlined,
          label: 'Sampling interval',
          value: 'Every 5 seconds',
        ),
      ],
    );
  }

  static String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$d/$mo/${dt.year}  $h:$m:$s';
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '${h}h ${m}m ${s}s' : '${m}m ${s}s';
  }
}

class _FooterRow extends StatelessWidget {
  const _FooterRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueMaxLines = 1,
  });
  final IconData icon;
  final String label;
  final String value;
  final int valueMaxLines;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Flexible(
          flex: 2,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 3,
          child: Text(
            value,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
            maxLines: valueMaxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small primitives
// ─────────────────────────────────────────────────────────────────────────────

class _SubsectionLabel extends StatelessWidget {
  const _SubsectionLabel({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 13, color: cs.primary),
        const SizedBox(width: 5),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cs.onSurfaceVariant),
          const SizedBox(height: 5),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
