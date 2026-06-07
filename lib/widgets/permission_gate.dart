import 'package:flutter/material.dart';

import '../permissions/app_permission.dart';

/// A reusable widget that wraps screen content and shows an actionable
/// permission error state when the given [state] blocks usage.
///
/// When [state] is [AppPermissionState.granted], [child] is rendered as-is.
/// Otherwise a full-screen error card is displayed with a context-appropriate
/// call-to-action.
class PermissionGate extends StatelessWidget {
  const PermissionGate({
    super.key,
    required this.permission,
    required this.state,
    required this.child,
    required this.onRequest,
    required this.onOpenSettings,
    this.onOpenLocationSettings,
  });

  /// The permission being guarded.
  final AppPermission permission;

  /// The current state of the permission.
  final AppPermissionState state;

  /// The wrapped content, shown only when [state] is granted.
  final Widget child;

  /// Called when the user taps the "Grant Permission" button.
  /// Only shown when [state] is [AppPermissionState.denied].
  final VoidCallback onRequest;

  /// Called when the user taps "Open Settings".
  /// Shown when [state] is [AppPermissionState.permanentlyDenied].
  final VoidCallback onOpenSettings;

  /// Called when the user taps "Enable Location Services".
  /// Only relevant for [AppPermission.location] with [AppPermissionState.serviceDisabled].
  final VoidCallback? onOpenLocationSettings;

  @override
  Widget build(BuildContext context) {
    if (state.isGranted || state == AppPermissionState.unknown) {
      return child;
    }

    if (state == AppPermissionState.checking) {
      return const Center(child: CircularProgressIndicator());
    }

    return _PermissionErrorView(
      permission: permission,
      state: state,
      onRequest: onRequest,
      onOpenSettings: onOpenSettings,
      onOpenLocationSettings: onOpenLocationSettings,
    );
  }
}

class _PermissionErrorView extends StatelessWidget {
  const _PermissionErrorView({
    required this.permission,
    required this.state,
    required this.onRequest,
    required this.onOpenSettings,
    this.onOpenLocationSettings,
  });

  final AppPermission permission;
  final AppPermissionState state;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenLocationSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final (IconData icon, Color iconColor, String headline, String body) =
        _content(cs);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: iconColor),
            ),
            const SizedBox(height: 24),

            // Headline
            Text(
              headline,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            // Body
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Primary action button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _primaryAction,
                icon: Icon(_primaryIcon),
                label: Text(_primaryLabel),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            // Secondary action for permanently denied (allows re-trying without
            // settings if the status was stale).
            if (state.isPermanentlyDenied) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onRequest,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Try Again'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (IconData, Color, String, String) _content(ColorScheme cs) {
    switch (state) {
      case AppPermissionState.serviceDisabled:
        return (
          Icons.location_off_rounded,
          Colors.orangeAccent,
          'Location Services Disabled',
          'GPS is turned off on your device. NetScope needs location services '
              'to record drive routes and map signal measurements.',
        );
      case AppPermissionState.permanentlyDenied:
        return (
          Icons.lock_outline_rounded,
          cs.error,
          '${permission.displayName} Permission Required',
          'You permanently denied this permission. '
              'Open your device settings to grant access so NetScope can work correctly.\n\n'
              '${permission.rationale}',
        );
      case AppPermissionState.denied:
      default:
        return (
          Icons.shield_outlined,
          cs.primary,
          '${permission.displayName} Permission Needed',
          permission.rationale,
        );
    }
  }

  VoidCallback get _primaryAction {
    if (state.isServiceDisabled) {
      return onOpenLocationSettings ?? onOpenSettings;
    }
    if (state.isPermanentlyDenied) {
      return onOpenSettings;
    }
    return onRequest;
  }

  IconData get _primaryIcon {
    if (state.isServiceDisabled) return Icons.settings_outlined;
    if (state.isPermanentlyDenied) return Icons.open_in_new_rounded;
    return Icons.lock_open_rounded;
  }

  String get _primaryLabel {
    if (state.isServiceDisabled) return 'Enable Location Services';
    if (state.isPermanentlyDenied) return 'Open Settings';
    return 'Grant Permission';
  }
}

/// A compact, non-blocking warning banner for degraded-mode permissions
/// (e.g. phone-state denied means signal metrics are unavailable).
class PermissionWarningBanner extends StatelessWidget {
  const PermissionWarningBanner({
    super.key,
    required this.message,
    required this.onTap,
    this.onDismiss,
  });

  final String message;

  /// Called when the user taps the banner (e.g. to open settings).
  final VoidCallback onTap;

  /// If provided, a dismiss icon is shown.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orangeAccent.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orangeAccent,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              if (onDismiss != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
