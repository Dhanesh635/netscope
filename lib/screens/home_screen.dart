import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../permissions/app_permission.dart';
import '../permissions/permission_manager.dart';
import '../recording/recording_state.dart';
import '../state/home_dashboard_state.dart';
import '../widgets/ai_prediction_card.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/info_tile.dart';
import '../widgets/metric_card.dart';
import '../widgets/permission_gate.dart';
import '../widgets/session_summary_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _phoneBannerDismissed = false;
  bool _bgBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check permissions when the user returns from Settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<PermissionManager>().checkAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = context.watch<HomeDashboardState>();
    final permManager = context.watch<PermissionManager>();
    final colorScheme = Theme.of(context).colorScheme;
    final locationState = permManager.stateFor(AppPermission.location);
    final phoneState = permManager.stateFor(AppPermission.phoneState);

    // Show the last recording error as a snack bar once.
    final recordingError = dashboardState.lastRecordingError;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (recordingError != null && recordingError.isBlocker) {
        _showErrorSnackBar(context, recordingError.message);
      }
    });

    return AppScaffold(
      title: 'NetScope 5G',
      subtitle: dashboardState.liveStatusLabel,
      actions: [
        IconButton(
          onPressed: () => context.read<HomeDashboardState>().runSpeedTest(),
          icon: const Icon(Icons.speed),
          tooltip: 'Run Speed Test',
        ),
        IconButton.filledTonal(
          onPressed: () {},
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: PermissionGate(
        permission: AppPermission.location,
        state: locationState,
        onRequest: () => permManager.requestLocation(),
        onOpenSettings: () => permManager.openAppSettings(),
        onOpenLocationSettings: () => permManager.openLocationSettings(),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Non-blocking warning banners ────────────────────────────────
              if (!phoneState.isGranted && !_phoneBannerDismissed) ...[
                PermissionWarningBanner(
                  message:
                      'Phone state permission denied. Signal metrics (RSRP, RSRQ, SINR) '
                      'are unavailable. Tap to grant.',
                  onTap: () => permManager.requestPhoneState(),
                  onDismiss: () =>
                      setState(() => _phoneBannerDismissed = true),
                ),
                const SizedBox(height: 12),
              ],
              if (!permManager.backgroundLocationGranted &&
                  !_bgBannerDismissed &&
                  phoneState.isGranted) ...[
                PermissionWarningBanner(
                  message:
                      'Background location not granted. Recording only works '
                      'while this app is open. Tap to grant.',
                  onTap: () => permManager.requestBackgroundLocation(),
                  onDismiss: () => setState(() => _bgBannerDismissed = true),
                ),
                const SizedBox(height: 12),
              ],

              // ── Metric grid ─────────────────────────────────────────────────
              LayoutBuilder(builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width > 600 ? 3 : 2;

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 1.25,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    MetricCard(
                      title: 'RSRP',
                      value: dashboardState.rsrpLabel,
                      unit: 'dBm',
                      icon: Icons.signal_cellular_alt,
                    ),
                    MetricCard(
                      title: 'RSRQ',
                      value: dashboardState.rsrqLabel,
                      unit: 'dB',
                      icon: Icons.monitor_heart,
                    ),
                    MetricCard(
                      title: 'SINR',
                      value: dashboardState.sinrLabel,
                      unit: 'dB',
                      icon: Icons.flash_on,
                    ),
                    MetricCard(
                      title: 'Download',
                      value: dashboardState.downloadLabel,
                      unit: 'Mbps',
                      icon: Icons.download_rounded,
                      iconColor: Colors.greenAccent,
                    ),
                    MetricCard(
                      title: 'Upload',
                      value: dashboardState.uploadLabel,
                      unit: 'Mbps',
                      icon: Icons.upload_rounded,
                      iconColor: Colors.blueAccent,
                    ),
                    MetricCard(
                      title: 'PCI',
                      value: dashboardState.pciLabel,
                      unit: 'id',
                      icon: Icons.lan_outlined,
                    ),
                  ],
                );
              }),
              const SizedBox(height: 20),

              // ── Info tiles ──────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: InfoTile(
                      icon: Icons.business,
                      label: 'Carrier',
                      value: dashboardState.carrierLabel,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InfoTile(
                      icon: Icons.five_g,
                      label: 'Network Type',
                      value: dashboardState.networkTypeLabel,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InfoTile(
                      icon: Icons.speed,
                      label: 'Velocity',
                      value: '${dashboardState.velocityLabel} km/h',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── AI Prediction ───────────────────────────────────────────────
              AiPredictionCard(
                measurement: dashboardState.latestMeasurement,
              ),
              const SizedBox(height: 20),

              // ── Session Summary ─────────────────────────────────────────────
              const SessionSummaryCard(),
              const SizedBox(height: 20),

              // ── Recording control buttons ───────────────────────────────────
              if (dashboardState.isRecording)
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: () {
                            if (dashboardState.isPaused) {
                              context.read<HomeDashboardState>().resumeRecording();
                            } else {
                              context.read<HomeDashboardState>().pauseRecording();
                            }
                          },
                          icon: Icon(
                            dashboardState.isPaused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                          ),
                          label: Text(
                            dashboardState.isPaused ? 'RESUME' : 'PAUSE',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor:
                                colorScheme.primaryContainer.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: () =>
                              context.read<HomeDashboardState>().stopRecording(),
                          icon: const Icon(Icons.stop_rounded),
                          label: const Text(
                            'STOP',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: colorScheme.errorContainer,
                            foregroundColor: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () =>
                        context.read<HomeDashboardState>().startRecording(),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      dashboardState.startButtonLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor:
                          colorScheme.primaryContainer.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Settings',
          onPressed: () => context.read<PermissionManager>().openAppSettings(),
        ),
      ),
    );
  }
}
