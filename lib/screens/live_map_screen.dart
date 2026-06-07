import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../map/map_layer.dart';
import '../map/map_service.dart';
import '../recording/recording_service.dart';
import '../state/home_dashboard_state.dart';
import '../widgets/glass_card.dart';

class LiveMapScreen extends StatelessWidget {
  const LiveMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;
          final mapService = context.watch<MapService>();
          final dashboardState = context.watch<HomeDashboardState>();

          return Stack(
            children: [
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
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        compassEnabled: true,
                        tiltGesturesEnabled: true,
                        rotateGesturesEnabled: true,
                        buildingsEnabled: true,
                        onCameraMoveStarted: () {},
                      ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorScheme.surface.withValues(alpha: 0.10),
                      Colors.transparent,
                      colorScheme.surface.withValues(alpha: 0.20),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Stack(
                  children: [
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
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
                            onLayerChanged: mapService.setActiveLayer,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: _RecordingControlPanel(isCompact: isCompact),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

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
              selectedColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.7),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    metric.value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
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
        onPressed: state.isRecording
            ? null
            : () => recordingService.startRecording(),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
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
                    for (var index = 0; index < children.length; index++) ...[
                      Expanded(child: children[index]),
                      if (index != children.length - 1)
                        const SizedBox(width: 12),
                    ],
                  ],
                ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}


