import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../location/location_provider.dart';
import '../models/network_measurement.dart';
import '../recording/recording_service.dart';
import '../recording/recording_state.dart';
import '../utils/signal_color.dart';
import 'map_layer.dart';

class MapService extends ChangeNotifier {
  MapService({LatLng initialCameraTarget = _defaultCameraTarget})
    : _initialCameraTarget = initialCameraTarget;

  static const LatLng _defaultCameraTarget = LatLng(
    37.42796133580664,
    -122.085749655962,
  );

  final LatLng _initialCameraTarget;

  LocationProvider? _locationProvider;
  RecordingService? _recordingService;
  GoogleMapController? _controller;
  Position? _currentPosition;

  final Set<Marker> _markers = <Marker>{};
  final Set<Circle> _measurementCircles = <Circle>{};
  final Set<Polyline> _polylines = <Polyline>{};
  final List<LatLng> _routePoints = <LatLng>[];

  bool _isSessionActive = false;
  bool _isRecordingRoute = false;
  int _renderedMeasurementCount = 0;
  MapLayer _activeLayer = MapLayer.signalStrength;
  bool _hasInitialCameraPosition = false;

  Set<Marker> get markers => Set.unmodifiable(_markers);
  Set<Circle> get circles => Set.unmodifiable(_measurementCircles);
  Set<Polyline> get polylines => Set.unmodifiable(_polylines);
  MapLayer get activeLayer => _activeLayer;

  CameraPosition get initialCameraPosition => CameraPosition(
    target: initialCameraTarget,
    zoom: _currentPosition == null ? 2 : 17,
  );

  LatLng get initialCameraTarget =>
      _currentPosition == null ? _initialCameraTarget : _currentLatLng!;

  LatLng? get currentLocation => _currentLatLng;

  LatLng? get _currentLatLng => _currentPosition == null
      ? null
      : LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

  void attachSources(
    LocationProvider locationProvider,
    RecordingService recordingService,
  ) {
    if (identical(_locationProvider, locationProvider) &&
        identical(_recordingService, recordingService)) {
      _syncFromSources(notify: false);
      return;
    }

    _locationProvider?.removeListener(_syncFromSources);
    _recordingService?.removeListener(_syncFromSources);

    _locationProvider = locationProvider;
    _recordingService = recordingService;

    _locationProvider?.addListener(_syncFromSources);
    _recordingService?.addListener(_syncFromSources);
    _syncFromSources(notify: false);
  }

  Future<void> attachController(GoogleMapController controller) async {
    _controller = controller;
    if (_currentPosition != null) {
      await _moveCameraToCurrentLocation(force: true);
    }
  }

  void setActiveLayer(MapLayer layer) {
    if (_activeLayer == layer) return;
    _activeLayer = layer;
    _rebuildMeasurementCircles();
    notifyListeners();
  }

  void _syncFromSources({bool notify = true}) {
    final position = _locationProvider?.currentPosition;
    final recordingState = _recordingService?.state;
    final isRecording = recordingState?.isRecording ?? false;
    final isPaused = recordingState?.isPaused ?? false;

    _updateCurrentPosition(position, notify: notify);
    _setRecordingState(isRecording, isPaused, notify: notify);
    _syncMeasurementCircles(recordingState, notify: notify);
  }

  void _updateCurrentPosition(Position? position, {bool notify = true}) {
    if (position == null) {
      return;
    }

    _currentPosition = position;
    final latLng = _currentLatLng;
    if (latLng == null) {
      return;
    }

    _markers.removeWhere(
      (marker) => marker.markerId.value == 'current_location',
    );
    _markers.add(
      Marker(
        markerId: const MarkerId('current_location'),
        position: latLng,
        infoWindow: const InfoWindow(title: 'Current Location'),
        zIndexInt: 2,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );

    if (_isRecordingRoute) {
      _appendRoutePoint(latLng, notify: notify);
    }

    if (notify) {
      notifyListeners();
    }
    
    if (!_hasInitialCameraPosition) {
      unawaited(_moveCameraToCurrentLocation(force: true));
      _hasInitialCameraPosition = true;
    }
  }

  void _setRecordingState(bool isRecording, bool isPaused, {bool notify = true}) {
    if (isRecording && !_isSessionActive) {
      // New session started or resumed from previous run
      _routePoints.clear();
      _measurementCircles.clear();
      _renderedMeasurementCount = 0;

      final measurements = _recordingService?.capturedMeasurements ?? [];
      if (measurements.isNotEmpty) {
        for (final m in measurements) {
          _routePoints.add(LatLng(m.latitude, m.longitude));
        }
        _rebuildMeasurementCircles();
      } else {
        final latLng = _currentLatLng;
        if (latLng != null) {
          _routePoints.add(latLng);
        }
      }
    }

    _isSessionActive = isRecording;
    _isRecordingRoute = isRecording && !isPaused;

    _refreshPolyline(notify: notify);
  }

  void _appendRoutePoint(LatLng latLng, {bool notify = true}) {
    if (_routePoints.isEmpty) {
      _routePoints.add(latLng);
      _refreshPolyline(notify: notify);
      return;
    }

    final previous = _routePoints.last;
    final distance = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      latLng.latitude,
      latLng.longitude,
    );

    if (distance < 5) {
      return;
    }

    _routePoints.add(latLng);
    _refreshPolyline(notify: notify);
  }

  void _refreshPolyline({bool notify = true}) {
    _polylines.removeWhere(
      (polyline) => polyline.polylineId.value == 'recorded_route',
    );

    if (_routePoints.length >= 2) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('recorded_route'),
          points: List<LatLng>.unmodifiable(_routePoints),
          color: const Color(0xFF00BFFF).withValues(alpha: 0.5),
          width: 5,
          geodesic: true,
        ),
      );
    }

    if (notify) {
      notifyListeners();
    }
  }

  void _syncMeasurementCircles(RecordingState? recordingState, {bool notify = true}) {
    if (recordingState?.isRecording != true) {
      return;
    }

    final measurements = _recordingService?.capturedMeasurements;
    if (measurements == null ||
        measurements.length <= _renderedMeasurementCount) {
      return;
    }

    for (
      var index = _renderedMeasurementCount;
      index < measurements.length;
      index++
    ) {
      _measurementCircles.add(
        _circleForMeasurement(measurements[index], index + 1),
      );
    }

    _renderedMeasurementCount = measurements.length;
    if (notify) {
      notifyListeners();
    }
  }

  void _rebuildMeasurementCircles() {
    _measurementCircles.clear();
    final measurements = _recordingService?.capturedMeasurements;
    if (measurements == null) return;

    for (var i = 0; i < measurements.length; i++) {
      _measurementCircles.add(_circleForMeasurement(measurements[i], i + 1));
    }
    _renderedMeasurementCount = measurements.length;
  }

  Circle _circleForMeasurement(NetworkMeasurement measurement, int index) {
    final color = switch (_activeLayer) {
      MapLayer.signalStrength => signalColorForRsrp(measurement.rsrp),
      MapLayer.sinr => signalColorForSinr(measurement.sinr),
      MapLayer.downloadSpeed => signalColorForDownload(measurement.download),
    };

    return Circle(
      circleId: CircleId('measurement_$index'),
      center: LatLng(measurement.latitude, measurement.longitude),
      radius: 8,
      fillColor: color.withValues(alpha: 0.6),
      strokeWidth: 2,
      strokeColor: color,
    );
  }

  Future<void> _moveCameraToCurrentLocation({bool force = false}) async {
    final latLng = _currentLatLng;
    final controller = _controller;

    if (latLng == null || controller == null) {
      return;
    }

    if (force) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: 17),
        ),
      );
    }
  }

  @override
  void dispose() {
    _locationProvider?.removeListener(_syncFromSources);
    _recordingService?.removeListener(_syncFromSources);
    super.dispose();
  }
}
