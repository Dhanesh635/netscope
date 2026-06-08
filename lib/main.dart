import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';


import 'location/location_provider.dart';
import 'location/location_service.dart';
import 'map/map_service.dart';
import 'navigation/app_navigation_shell.dart';
import 'permissions/permission_manager.dart';
import 'recording/background_recording_service.dart';
import 'recording/recording_service.dart';


import 'state/home_dashboard_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background service before running the app.
  await BackgroundRecordingService.initializeService();

  runApp(const NetScopeApp());
}

class NetScopeApp extends StatelessWidget {
  const NetScopeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[


        // ── 1. PermissionManager: top of the tree, no dependencies ───────────
        ChangeNotifierProvider<PermissionManager>(
          create: (_) {
            final manager = PermissionManager();
            // Kick off a silent check on startup (no dialogs shown).
            unawaited(manager.checkAll());
            return manager;
          },
        ),

        // ── 2. LocationProvider: depends on PermissionManager ─────────────────
        ChangeNotifierProxyProvider<PermissionManager, LocationProvider>(
          create: (context) => LocationProvider(
            permissionManager: context.read<PermissionManager>(),
            locationService: const LocationService(),
          ),
          update: (context, permManager, previous) {
            final provider = previous ??
                LocationProvider(
                  permissionManager: permManager,
                  locationService: const LocationService(),
                );
            // Re-attempt tracking whenever permission state changes.
            if (permManager.locationGranted && !provider.isTracking) {
              unawaited(provider.startTracking());
            }
            return provider;
          },
        ),

        // ── 3. RecordingService: depends on PermissionManager
        ChangeNotifierProxyProvider<PermissionManager, RecordingService>(
          create: (context) => RecordingService(
            permissionManager: context.read<PermissionManager>(),
          ),
          update: (context, permManager, previous) =>
              previous ??
              RecordingService(
                permissionManager: permManager,
              ),
        ),

        // ── 4. HomeDashboardState: proxies LocationProvider + RecordingService ─
        ChangeNotifierProxyProvider2<LocationProvider, RecordingService,
            HomeDashboardState>(
          create: (_) => HomeDashboardState(),
          update: (
            _,
            locationProvider,
            recordingService,
            homeDashboardState,
          ) {
            final service = homeDashboardState ?? HomeDashboardState();
            service.attachSources(locationProvider, recordingService);
            return service;
          },
        ),

        // ── 5. MapService: proxies LocationProvider + RecordingService ─────────
        ChangeNotifierProxyProvider2<LocationProvider, RecordingService,
            MapService>(
          create: (_) => MapService(),
          update: (_, locationProvider, recordingService, mapService) {
            final service = mapService ?? MapService();
            service.attachSources(locationProvider, recordingService);
            return service;
          },
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'NetScope',
        theme: AppTheme.darkTheme,
        home: const AppNavigationShell(),
      ),
    );
  }
}
