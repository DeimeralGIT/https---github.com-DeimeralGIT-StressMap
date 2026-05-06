import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/indicator_filters.dart';
import '../models/map_bounds.dart';
import '../models/stress_location.dart';
import '../services/stress_aggregation_service.dart';
import '../utils/app_logger.dart';

class StressMapController extends ChangeNotifier {
  StressMapController({StressAggregationService? aggregationService})
      : _aggregationService = aggregationService ?? StressAggregationService();

  final StressAggregationService _aggregationService;
  static const minimumDataZoom = 6.2;

  IndicatorFilters filters = const IndicatorFilters();
  List<StressLocation> locations = const [];
  StressLocation? selectedLocation;
  LatLng? currentLocation;
  LatLng lastCenter = const LatLng(40.7484, -73.9857);
  MapBounds lastBounds = const MapBounds(
    north: 41.05,
    south: 40.45,
    east: -73.55,
    west: -74.35,
  );
  double lastZoom = 3;
  String? locationMessage;
  bool isLoading = true;
  bool isLocating = false;
  bool shouldShowZoomInTip = false;
  int _loadToken = 0;
  bool _isFetchingViewport = false;
  ({LatLng center, double zoom, MapBounds bounds, bool forceRefresh})?
      _pendingViewport;

  Future<void> load() async {
    await loadForViewport(
        center: lastCenter, zoom: lastZoom, bounds: lastBounds);
  }

  void updateZoomInTip({
    required double zoom,
    required MapBounds bounds,
  }) {
    final nextValue = zoom < minimumDataZoom || bounds.isTooBroadForPlaceLookup;
    if (shouldShowZoomInTip == nextValue) {
      return;
    }

    shouldShowZoomInTip = nextValue;
    notifyListeners();
  }

  Future<void> loadForViewport({
    required LatLng center,
    required double zoom,
    required MapBounds bounds,
    bool forceRefresh = false,
  }) async {
    if (_isFetchingViewport) {
      AppLogger.info(
        'StressMapController',
        'Queueing viewport request zoom=${zoom.toStringAsFixed(2)} center=${center.latitude.toStringAsFixed(3)},${center.longitude.toStringAsFixed(3)}',
      );
      _pendingViewport = (
        center: center,
        zoom: zoom,
        bounds: bounds,
        forceRefresh: forceRefresh,
      );
      return;
    }

    AppLogger.info(
      'StressMapController',
      'Loading viewport zoom=${zoom.toStringAsFixed(2)} bounds=${bounds.north.toStringAsFixed(2)},${bounds.south.toStringAsFixed(2)},${bounds.east.toStringAsFixed(2)},${bounds.west.toStringAsFixed(2)}',
    );
    lastCenter = center;
    lastZoom = zoom;
    lastBounds = bounds;
    final token = ++_loadToken;
    _isFetchingViewport = true;
    isLoading = true;
    notifyListeners();

    try {
      if (zoom < minimumDataZoom || bounds.isTooBroadForPlaceLookup) {
        AppLogger.info(
          'StressMapController',
          'Viewport gated. zoom=${zoom.toStringAsFixed(2)} boundsTooBroad=${bounds.isTooBroadForPlaceLookup} maxSpan=${bounds.latitudeSpan.toStringAsFixed(2)}x${bounds.longitudeSpan.toStringAsFixed(2)}',
        );
        if (token != _loadToken) return;
        locations = const [];
        selectedLocation = null;
        shouldShowZoomInTip = true;
        return;
      }

      shouldShowZoomInTip = false;
      final nextLocations =
          await _aggregationService.loadStressLocationsForArea(
        center: center,
        zoom: zoom,
        bounds: bounds,
        filters: filters,
        forceRefresh: forceRefresh,
      );

      if (token != _loadToken) return;
      locations = nextLocations;
      selectedLocation = null;
      AppLogger.info(
        'StressMapController',
        'Viewport load complete with ${nextLocations.length} locations.',
      );
    } catch (error) {
      AppLogger.error('StressMapController', 'Viewport load failed.', error);
      rethrow;
    } finally {
      if (token == _loadToken) {
        isLoading = false;
      }
      _isFetchingViewport = false;
      notifyListeners();

      final pending = _pendingViewport;
      _pendingViewport = null;
      if (pending != null &&
          (pending.center != lastCenter ||
              pending.zoom != lastZoom ||
              pending.bounds != lastBounds ||
              pending.forceRefresh)) {
        await loadForViewport(
          center: pending.center,
          zoom: pending.zoom,
          bounds: pending.bounds,
          forceRefresh: pending.forceRefresh,
        );
      }
    }
  }

  void selectLocation(StressLocation location) {
    selectedLocation = location;
    notifyListeners();
  }

  void clearSelection() {
    selectedLocation = null;
    notifyListeners();
  }

  Future<LatLng?> locateUser() async {
    isLocating = true;
    locationMessage = null;
    notifyListeners();
    AppLogger.info('StressMapController', 'Locating current user position.');

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        locationMessage = 'location.servicesDisabled';
        AppLogger.warning('StressMapController', 'Location services are disabled.');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        locationMessage = 'location.permissionDenied';
        AppLogger.warning('StressMapController', 'Location permission denied.');
        return null;
      }

      if (permission == LocationPermission.deniedForever) {
        locationMessage = 'location.permissionDeniedForever';
        AppLogger.warning(
          'StressMapController',
          'Location permission denied forever.',
        );
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      currentLocation = LatLng(position.latitude, position.longitude);
      AppLogger.info(
        'StressMapController',
        'Location acquired at ${position.latitude.toStringAsFixed(4)},${position.longitude.toStringAsFixed(4)}',
      );
      return currentLocation;
    } catch (error) {
      locationMessage = 'location.unavailable';
      AppLogger.error('StressMapController', 'Failed to locate user.', error);
      return null;
    } finally {
      isLocating = false;
      notifyListeners();
    }
  }

  Future<void> updateFilters(IndicatorFilters nextFilters) async {
    setFilters(nextFilters);
    await refetchCurrentViewport(forceRefresh: true);
  }

  void setFilters(IndicatorFilters nextFilters) {
    if (_filtersEqual(filters, nextFilters)) {
      return;
    }
    filters = nextFilters;
    notifyListeners();
  }

  Future<void> refetchCurrentViewport({bool forceRefresh = false}) async {
    await loadForViewport(
      center: lastCenter,
      zoom: lastZoom,
      bounds: lastBounds,
      forceRefresh: forceRefresh,
    );
  }

  bool _filtersEqual(IndicatorFilters a, IndicatorFilters b) {
    return a.airQuality == b.airQuality &&
        a.populationDensity == b.populationDensity &&
        a.noise == b.noise &&
        a.traffic == b.traffic &&
        a.costOfLiving == b.costOfLiving &&
        a.safety == b.safety;
  }
}
