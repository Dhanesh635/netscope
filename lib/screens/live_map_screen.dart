import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../map/map_layer.dart';
import '../map/map_service.dart';
import '../map/risk_marker_icon.dart';
import '../models/network_measurement.dart';
import '../recording/recording_service.dart';
import '../state/home_dashboard_state.dart';
import '../widgets/glass_card.dart';

class LiveMapScreen extends StatelessWidget {
  const LiveMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;
          final mapService = context.watch<MapService>();
          final dashboardState = context.watch<HomeDashboardState>();

          return Stack(
            children: [
              // ── Map ────────────────────────────────────────────────────────
              Positioned.fill(
                child: isTest
                    ? const Center(child: Text('GoogleMap placeholder'))
                    : GoogleMap(
                        initialCameraPosition: mapService.initialCameraPosition,
                        onMapCreated: mapService.attachController,
                        markers: mapService.markers,
                        circles: mapService.circles,
                        polylines: mapService.polylines,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        compassEnabled: true,
                        tiltGesturesEnabled: true,
                        rotateGesturesEnabled: true,
                        buildingsEnabled: true,
                        onCameraMoveStarted: () =>
                            context.read<MapService>().disableAutoFollow(),
                        onTap: (_) =>
                            context.read<MapService>().clearSelection(),
                      ),
              ),

              // ── Subtle gradient vignette ───────────────────────────────────
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.10),
                          Colors.transparent,
                          Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Top overlay: signal chips + layer toggle ───────────────────
              Positioned(
                top: 8,
                left: 16,
                right: 16,
                child: Column(
                  children: [
                    _MetricCardRow(
                      isCompact: isCompact,
                      metrics: [
                        _MetricCardData(
                          title: 'RSRP',
                          value: '${dashboardState.rsrpLabel} dBm',
                        ),
                        _MetricCardData(
                          title: 'SINR',
                          value: '${dashboardState.sinrLabel} dB',
                        ),
                        _MetricCardData(
                          title: 'PCI',
                          value: dashboardState.pciLabel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _LayerToggleRow(
                      activeLayer: mapService.activeLayer,
                      onLayerChanged:
                          context.read<MapService>().setActiveLayer,
                    ),
                  ],
                ),
              ),

              // ── Right-side FABs: recenter + legend ─────────────────────────
              Positioned(
                right: 16,
                bottom: isCompact ? 200 : 180,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!mapService.autoFollow) ...[
                      _RecenterButton(
                        onTap: () =>
                            context.read<MapService>().recenter(),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (mapService.activeLayer == MapLayer.aiRisk)
                      const _RiskLegendButton(),
                  ],
                ),
              ),

              // ── Marker popup sheet ─────────────────────────────────────────
              if (mapService.selectedMeasurement != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: isCompact ? 192 : 172,
                  child: _MeasurementPopup(
                    measurement: mapService.selectedMeasurement!,
                    onClose: () =>
                        context.read<MapService>().clearSelection(),
                  ),
                ),

              // ── Bottom: recording controls ─────────────────────────────────
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: _RecordingControlPanel(isCompact: isCompact),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layer toggle row
// ─────────────────────────────────────────────────────────────────────────────

class _LayerToggleRow extends StatelessWidget {
  const _LayerToggleRow({
    required this.activeLayer,
    required this.onLayerChanged,
  });

  final MapLayer activeLayer;
  final ValueChanged<MapLayer> onLayerChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: MapLayer.values.map((layer) {
          final isSelected = activeLayer == layer;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(layer.label),
              selected: isSelected,
              onSelected: (_) => onLayerChanged(layer),
              backgroundColor: Colors.black.withValues(alpha: 0.3),
              selectedColor: layer == MapLayer.aiRisk && isSelected
                  ? const Color(0xFF7C4DFF).withValues(alpha: 0.75)
                  : Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.70),
              avatar: layer == MapLayer.aiRisk
                  ? Icon(
                      Icons.psychology_outlined,
                      size: 14,
                      color: isSelected ? Colors.white : Colors.white54,
                    )
                  : null,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Signal metric cards
// ─────────────────────────────────────────────────────────────────────────────

class _MetricCardData {
  const _MetricCardData({required this.title, required this.value});
  final String title;
  final String value;
}

class _MetricCardRow extends StatelessWidget {
  const _MetricCardRow({required this.metrics, required this.isCompact});

  final List<_MetricCardData> metrics;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final cards = metrics
        .map(
          (metric) => Expanded(
            child: GlassCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.title,
                    style:
                        Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    metric.value,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 0 : 12),
      child: Row(
        children: [
          cards[0],
          const SizedBox(width: 12),
          cards[1],
          const SizedBox(width: 12),
          cards[2],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recenter FAB
// ─────────────────────────────────────────────────────────────────────────────

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'recenter',
      onPressed: onTap,
      backgroundColor:
          Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
      child: Icon(
        Icons.my_location_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Risk legend FAB + popover
// ─────────────────────────────────────────────────────────────────────────────

class _RiskLegendButton extends StatefulWidget {
  const _RiskLegendButton();

  @override
  State<_RiskLegendButton> createState() => _RiskLegendButtonState();
}

class _RiskLegendButtonState extends State<_RiskLegendButton> {
  bool _open = false;

  static const _entries = [
    ('Low', Color(0xFF00E676)),
    ('Medium', Color(0xFFFFD600)),
    ('High', Color(0xFFFF9800)),
    ('Critical', Color(0xFFFF5252)),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_open)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: cs.outline.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Risk Level',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                for (final (label, color) in _entries) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white, width: 1.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (label != 'Critical') const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        FloatingActionButton.small(
          heroTag: 'legend',
          onPressed: () => setState(() => _open = !_open),
          backgroundColor: cs.surface.withValues(alpha: 0.85),
          child: Icon(
            Icons.layers_outlined,
            color: _open ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Measurement popup card
// ─────────────────────────────────────────────────────────────────────────────

class _MeasurementPopup extends StatelessWidget {
  const _MeasurementPopup({
    required this.measurement,
    required this.onClose,
  });

  final NetworkMeasurement measurement;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
      child: Material(
        key: ValueKey(measurement.timestamp),
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: cs.outline.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle + close ──────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTimestamp(measurement.timestamp),
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onClose,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // ── Content ──────────────────────────────────────────────────
              SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Network section
                    _PopupSectionHeader(
                      icon: Icons.cell_tower_outlined,
                      title: 'Network Information',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PopupChip(
                            label: 'Carrier',
                            value: measurement.carrier),
                        _PopupChip(
                            label: 'Type',
                            value: measurement.networkType),
                        _PopupChip(
                            label: 'PCI',
                            value: measurement.pci.toString()),
                        _PopupChip(
                          label: 'RSRP',
                          value:
                              '${measurement.rsrp.toStringAsFixed(0)} dBm',
                        ),
                        _PopupChip(
                          label: 'RSRQ',
                          value:
                              '${measurement.rsrq.toStringAsFixed(0)} dB',
                        ),
                        _PopupChip(
                          label: 'SINR',
                          value: measurement.sinr != null
                              ? '${measurement.sinr!.toStringAsFixed(1)} dB'
                              : 'N/A',
                        ),
                        _PopupChip(
                          label: 'Velocity',
                          value:
                              '${(measurement.velocity * 3.6).toStringAsFixed(1)} km/h',
                        ),
                        _PopupChip(
                          label: 'Lat',
                          value:
                              measurement.latitude.toStringAsFixed(5),
                        ),
                        _PopupChip(
                          label: 'Lon',
                          value:
                              measurement.longitude.toStringAsFixed(5),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),

                    // AI section
                    _PopupSectionHeader(
                      icon: Icons.psychology_outlined,
                      title: 'AI Prediction',
                    ),
                    const SizedBox(height: 10),
                    _AiPredictionRow(measurement: measurement),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTimestamp(DateTime ts) {
    final h = ts.hour.toString().padLeft(2, '0');
    final m = ts.minute.toString().padLeft(2, '0');
    final s = ts.second.toString().padLeft(2, '0');
    return '$h:$m:$s — ${ts.day}/${ts.month}/${ts.year}';
  }
}

class _PopupSectionHeader extends StatelessWidget {
  const _PopupSectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

class _PopupChip extends StatelessWidget {
  const _PopupChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 10,
            ),
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

class _AiPredictionRow extends StatelessWidget {
  const _AiPredictionRow({required this.measurement});
  final NetworkMeasurement measurement;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final prob = measurement.handoverProbability;
    final probLabel = prob != null
        ? '${(prob * 100).toStringAsFixed(1)} %'
        : '—';

    final predLabel = measurement.prediction ?? '—';
    final riskLabel = measurement.riskLevel ?? '—';
    final qos = measurement.qosScore;
    final qosLabel =
        qos != null ? qos.toStringAsFixed(3) : '—';

    final riskColor = riskLevelColor(measurement.riskLevel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Risk chip — prominent colored badge
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: riskColor.withValues(alpha: 0.55),
                    width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: riskColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    riskLabel,
                    style:
                        Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: riskColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                predLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Probability + QoS side by side
        Row(
          children: [
            Expanded(
              child: _PopupChip(
                label: 'Probability',
                value: probLabel,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PopupChip(
                label: 'QoS Score',
                value: qosLabel,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recording control panel (unchanged logic, refreshed layout)
// ─────────────────────────────────────────────────────────────────────────────

class _RecordingControlPanel extends StatelessWidget {
  const _RecordingControlPanel({required this.isCompact});
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final recordingService = context.watch<RecordingService>();
    final state = recordingService.state;

    final children = [
      _ControlButton(
        icon: Icons.fiber_manual_record,
        label: 'Start Recording',
        accentColor: Colors.redAccent,
        onPressed:
            state.isRecording ? null : () => recordingService.startRecording(),
      ),
      _ControlButton(
        icon: state.isPaused ? Icons.play_arrow : Icons.pause,
        label: state.isPaused ? 'Resume Recording' : 'Pause Recording',
        onPressed: !state.isRecording
            ? null
            : state.isPaused
                ? () => recordingService.resumeRecording()
                : () => recordingService.pauseRecording(),
      ),
      _ControlButton(
        icon: Icons.stop,
        label: 'Stop Recording',
        onPressed: state.isRecording
            ? () => recordingService.stopRecording()
            : null,
      ),
    ];

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: isCompact
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final child in children) ...[
                    child,
                    const SizedBox(height: 10),
                  ],
                ],
              )
            : Row(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    Expanded(child: children[i]),
                    if (i != children.length - 1) const SizedBox(width: 12),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = accentColor ?? colorScheme.onSurface;

    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, color: foreground),
      label: Text(label, textAlign: TextAlign.center),
      style: FilledButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: colorScheme.surface.withValues(alpha: 0.35),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
