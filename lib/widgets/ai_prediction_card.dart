import 'package:flutter/material.dart';

import '../models/network_measurement.dart';

/// Risk level classification derived from the backend's [riskLevel] string.
enum _RiskLevel { low, medium, high, critical, unknown }

_RiskLevel _parseRisk(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'low':
      return _RiskLevel.low;
    case 'medium':
      return _RiskLevel.medium;
    case 'high':
      return _RiskLevel.high;
    case 'critical':
      return _RiskLevel.critical;
    default:
      return _RiskLevel.unknown;
  }
}

/// A self-contained, animated Material 3 card that displays the AI prediction
/// output from a [NetworkMeasurement].
///
/// Animates smoothly whenever [measurement] changes. Displays a placeholder
/// state when [measurement] is null or contains no prediction data.
class AiPredictionCard extends StatefulWidget {
  const AiPredictionCard({
    super.key,
    required this.measurement,
  });

  final NetworkMeasurement? measurement;

  @override
  State<AiPredictionCard> createState() => _AiPredictionCardState();
}

class _AiPredictionCardState extends State<AiPredictionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  // Cached values so we animate from old → new
  double? _probability;
  String? _predictionLabel;
  String? _riskLabel;
  double? _qosScore;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _updateValues(widget.measurement, animate: false);
  }

  @override
  void didUpdateWidget(AiPredictionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final m = widget.measurement;
    final old = oldWidget.measurement;

    // Only re-animate when the prediction data actually changed.
    final changed = m?.handoverProbability != old?.handoverProbability ||
        m?.prediction != old?.prediction ||
        m?.riskLevel != old?.riskLevel ||
        m?.qosScore != old?.qosScore;

    if (changed) {
      _updateValues(m, animate: true);
    }
  }

  void _updateValues(NetworkMeasurement? m, {required bool animate}) {
    _probability = m?.handoverProbability;
    _predictionLabel = m?.prediction;
    _riskLabel = m?.riskLevel;
    _qosScore = m?.qosScore;

    if (animate) {
      _controller.forward(from: 0.0);
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasPrediction =>
      _probability != null || _predictionLabel != null || _qosScore != null;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: _CardShell(
        child: _hasPrediction ? _PredictionBody(
          probability: _probability,
          predictionLabel: _predictionLabel,
          riskLabel: _riskLabel,
          qosScore: _qosScore,
        ) : const _EmptyBody(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Outer card shell — matches MetricCard / InfoTile styling
// ─────────────────────────────────────────────────────────────────────────────

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder shown before first prediction arrives
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        children: [
          Icon(Icons.psychology_outlined, color: cs.primary, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Prediction',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Waiting for first measurement…',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full prediction body
// ─────────────────────────────────────────────────────────────────────────────

class _PredictionBody extends StatelessWidget {
  const _PredictionBody({
    required this.probability,
    required this.predictionLabel,
    required this.riskLabel,
    required this.qosScore,
  });

  final double? probability;
  final String? predictionLabel;
  final String? riskLabel;
  final double? qosScore;

  @override
  Widget build(BuildContext context) {
    final risk = _parseRisk(riskLabel);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          _SectionHeader(),
          const SizedBox(height: 16),

          // ── 2-column grid: Probability + Prediction ────────────────────────
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _DataCell(
                    label: 'Probability',
                    child: _ProbabilityDisplay(probability: probability),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DataCell(
                    label: 'Prediction',
                    child: _PredictionBadge(label: predictionLabel),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── 2-column grid: Risk Level + QoS Score ─────────────────────────
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _DataCell(
                    label: 'Risk Level',
                    child: _RiskBadge(risk: risk, label: riskLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DataCell(
                    label: 'QoS Score',
                    child: _QosDisplay(score: qosScore),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header row
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.psychology_outlined, color: cs.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          'AI Prediction',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'LIVE',
            style: TextStyle(
              color: cs.primary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic inner cell (label + content)
// ─────────────────────────────────────────────────────────────────────────────

class _DataCell extends StatelessWidget {
  const _DataCell({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Probability display with animated arc gauge
// ─────────────────────────────────────────────────────────────────────────────

class _ProbabilityDisplay extends StatelessWidget {
  const _ProbabilityDisplay({required this.probability});
  final double? probability;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = probability ?? 0.0;
    final pctLabel =
        probability != null ? '${(pct * 100).toStringAsFixed(1)}%' : '—';

    // Color shifts from green → amber → red based on probability.
    final Color gaugeColor;
    if (pct < 0.4) {
      gaugeColor = const Color(0xFF00E676); // green
    } else if (pct < 0.7) {
      gaugeColor = const Color(0xFFFFD600); // amber
    } else {
      gaugeColor = const Color(0xFFFF5252); // red
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: probability != null ? pct : 0,
                backgroundColor: cs.outline.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          pctLabel,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: gaugeColor,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Prediction label badge (Handover / No Handover)
// ─────────────────────────────────────────────────────────────────────────────

class _PredictionBadge extends StatelessWidget {
  const _PredictionBadge({required this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (label == null) {
      return Text('—',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: cs.onSurfaceVariant));
    }

    final isHandover = label!.toLowerCase().contains('handover') &&
        !label!.toLowerCase().contains('no');

    final color = isHandover
        ? const Color(0xFFFF5252)
        : const Color(0xFF00E676);
    final icon = isHandover ? Icons.swap_horiz_rounded : Icons.check_circle_outline;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label!,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Risk level badge with color-coded dot
// ─────────────────────────────────────────────────────────────────────────────

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.risk, required this.label});
  final _RiskLevel risk;
  final String? label;

  static const _dot = {
    _RiskLevel.low: '🟢',
    _RiskLevel.medium: '🟡',
    _RiskLevel.high: '🟠',
    _RiskLevel.critical: '🔴',
    _RiskLevel.unknown: '⬜',
  };

  static const _color = {
    _RiskLevel.low: Color(0xFF00E676),
    _RiskLevel.medium: Color(0xFFFFD600),
    _RiskLevel.high: Color(0xFFFF9800),
    _RiskLevel.critical: Color(0xFFFF5252),
    _RiskLevel.unknown: Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color[risk] ?? Colors.grey;
    final dot = _dot[risk] ?? '⬜';
    final displayLabel = label ?? '—';

    return Row(
      children: [
        Text(dot, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            displayLabel,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QoS score display with a thin linear bar
// ─────────────────────────────────────────────────────────────────────────────

class _QosDisplay extends StatelessWidget {
  const _QosDisplay({required this.score});
  final double? score;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final value = score ?? 0.0;
    final label = score != null ? value.toStringAsFixed(3) : '—';

    // Higher QoS = greener
    final Color barColor;
    if (value >= 0.7) {
      barColor = const Color(0xFF00E676);
    } else if (value >= 0.4) {
      barColor = const Color(0xFFFFD600);
    } else {
      barColor = const Color(0xFFFF5252);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: barColor,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score != null ? value.clamp(0.0, 1.0) : 0,
            minHeight: 4,
            backgroundColor: cs.outline.withValues(alpha: 0.18),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}
