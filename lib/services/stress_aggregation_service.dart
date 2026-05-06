import 'package:latlong2/latlong.dart';

import '../models/discovered_place.dart';
import '../models/indicator_filters.dart';
import '../models/map_bounds.dart';
import '../models/stress_indicator.dart';
import '../models/stress_location.dart';
import '../models/urban_signal_profile.dart';
import '../utils/app_logger.dart';
import 'air_quality_service.dart';
import 'place_discovery_service.dart';
import 'stress_score_service.dart';
import 'urban_signals_service.dart';

class StressAggregationService {
  StressAggregationService({
    AirQualityService? airQualityService,
    PlaceDiscoveryService? placeDiscoveryService,
    UrbanSignalsService? urbanSignalsService,
    StressScoreService? scoreService,
  })  : _airQualityService = airQualityService ?? AirQualityService(),
        _placeDiscoveryService =
            placeDiscoveryService ?? PlaceDiscoveryService(),
        _urbanSignalsService = urbanSignalsService ?? UrbanSignalsService(),
        _scoreService = scoreService ?? const StressScoreService();

  final AirQualityService _airQualityService;
  final PlaceDiscoveryService _placeDiscoveryService;
  final UrbanSignalsService _urbanSignalsService;
  final StressScoreService _scoreService;
  final _locationCache = <String, StressLocation>{};

  Future<List<StressLocation>> loadStressLocations(
      IndicatorFilters filters) async {
    return const [];
  }

  Future<List<StressLocation>> loadStressLocationsForArea({
    required LatLng center,
    required double zoom,
    required MapBounds bounds,
    required IndicatorFilters filters,
    bool forceRefresh = false,
  }) async {
    try {
      AppLogger.info(
        'StressAggregationService',
        'Loading area data for zoom=${zoom.toStringAsFixed(2)}',
      );

      if (forceRefresh) {
        AppLogger.info(
          'StressAggregationService',
          'Force refresh requested. Clearing service and location caches.',
        );
        _locationCache.clear();
        _placeDiscoveryService.clearCache();
        _urbanSignalsService.clearCache();
        _airQualityService.clearCache();
      }

      final places = await _placeDiscoveryService.fetchPlacesInBounds(bounds);
      if (places.isEmpty) {
        AppLogger.warning(
          'StressAggregationService',
          'No places returned for current bounds.',
        );
        return const [];
      }

      final missingPlaces = places
          .where((place) => !_locationCache.containsKey(place.id))
          .toList();

      AppLogger.info(
        'StressAggregationService',
        'Resolved ${places.length} places. Cache hits=${places.length - missingPlaces.length}, misses=${missingPlaces.length}',
      );

      if (missingPlaces.isNotEmpty) {
        final signalProfiles = await _urbanSignalsService.fetchProfiles(
          bounds: bounds,
          places: missingPlaces,
        );
        final seeds = missingPlaces
            .map(
              (place) => _locationFromPlace(place, signalProfiles[place.id]),
            )
            .toList();

        final hydratedMissing = <StressLocation>[];
        for (final seed in seeds) {
          hydratedMissing.add(await _hydrateLocation(seed));
        }

        for (final location in hydratedMissing) {
          _locationCache[location.id] = location;
        }

        AppLogger.info(
          'StressAggregationService',
          'Hydrated and cached ${hydratedMissing.length} new locations.',
        );
      }

      return places
          .map((place) {
            final cached = _locationCache[place.id];
            if (cached == null) {
              return _withStressScore(
                _locationFromPlace(place, null),
                filters,
              );
            }

            return _withStressScore(
              cached.copyWith(
                name: '${place.name} (${place.placeType})',
                latitude: place.latitude,
                longitude: place.longitude,
              ),
              filters,
            );
          })
          .toList(growable: false);
    } catch (error) {
      AppLogger.error(
        'StressAggregationService',
        'Failed to load area data.',
        error,
      );
      return const [];
    }
  }

  List<StressLocation> recalculateMockLocations(IndicatorFilters filters) {
    return const [];
  }

  double _blend(double curatedValue, double apiValue) {
    return (curatedValue * 0.8 + apiValue * 0.2).clamp(0, 100);
  }

  Future<StressLocation> _hydrateLocation(StressLocation location) async {
    AppLogger.info(
      'StressAggregationService',
      'Hydrating location ${location.id} (${location.name})',
    );
    final results = await Future.wait<_IndicatorFetchResult>([
      Future.value(
        _IndicatorFetchResult(
          indicator: StressIndicator.populationDensity,
          value: location.populationDensity,
          isAvailable: !location.unavailableIndicators.contains(
            StressIndicator.populationDensity,
          ),
        ),
      ),
      _safeFetch(
        indicator: StressIndicator.airQuality,
        fallback: location.airQualityIndex,
        request: () => _airQualityService.fetchAirQualityIndex(
          latitude: location.latitude,
          longitude: location.longitude,
        ),
      ),
      _safeFetch(
        indicator: StressIndicator.noise,
        fallback: location.noiseLevel,
        request: () async => location.noiseLevel,
      ),
      _safeFetch(
        indicator: StressIndicator.traffic,
        fallback: location.trafficIndex,
        request: () async => location.trafficIndex,
      ),
      _safeFetch(
        indicator: StressIndicator.safety,
        fallback: location.safetyIndex,
        request: () async => location.safetyIndex,
      ),
    ]);

    final unavailable = results
        .where((result) => !result.isAvailable)
        .map((result) => result.indicator)
        .toSet()
      ..addAll(location.unavailableIndicators);

    final hydrated = location.copyWith(
      populationDensity: _blend(location.populationDensity, results[0].value),
      airQualityIndex: results[1].value.clamp(0, 100),
      noiseLevel: _blend(location.noiseLevel, results[2].value),
      costOfLivingIndex: location.costOfLivingIndex,
      trafficIndex: _blend(location.trafficIndex, results[3].value),
      safetyIndex: _blend(location.safetyIndex, results[4].value),
      unavailableIndicators: unavailable,
    );

    return hydrated;
  }

  StressLocation _withStressScore(
    StressLocation location,
    IndicatorFilters filters,
  ) {
    final available = _availableFilters(filters, location.unavailableIndicators);
    return location.copyWith(
      stressScore: _scoreService.calculate(location, available),
    );
  }

  Future<_IndicatorFetchResult> _safeFetch({
    required StressIndicator indicator,
    required double fallback,
    required Future<double> Function() request,
  }) async {
    try {
      final value = await request().timeout(const Duration(seconds: 8));
      AppLogger.info(
        'StressAggregationService',
        'Fetched ${indicator.name}=${value.toStringAsFixed(1)}',
      );
      return _IndicatorFetchResult(
        indicator: indicator,
        value: value,
        isAvailable: true,
      );
    } catch (error) {
      AppLogger.warning(
        'StressAggregationService',
        'Falling back for ${indicator.name} with value ${fallback.toStringAsFixed(1)}: $error',
      );
      return _IndicatorFetchResult(
        indicator: indicator,
        value: fallback,
        isAvailable: false,
      );
    }
  }

  StressLocation _locationFromPlace(
    DiscoveredPlace place,
    UrbanSignalProfile? signalProfile,
  ) {
    final populationScore = _populationToScore(place.population);
    final unavailable = {
      if (populationScore == null) StressIndicator.populationDensity,
      if (signalProfile == null) ...{
        StressIndicator.noise,
        StressIndicator.traffic,
        StressIndicator.costOfLiving,
        StressIndicator.safety,
      },
    };

    return StressLocation(
      id: place.id,
      name: '${place.name} (${place.placeType})',
      latitude: place.latitude,
      longitude: place.longitude,
      populationDensity: populationScore ?? 0,
      airQualityIndex: 0,
      noiseLevel: signalProfile?.noiseLevel ?? 0,
      costOfLivingIndex: signalProfile?.costOfLivingIndex ?? 0,
      trafficIndex: signalProfile?.trafficIndex ?? 0,
      safetyIndex: signalProfile?.safetyIndex ?? 0,
      stressScore: 0,
      unavailableIndicators: unavailable,
    );
  }

  double? _populationToScore(int? population) {
    if (population == null || population <= 0) return null;
    final normalized = (population.toDouble().clamp(1, 10000000) / 10000000);
    return (normalized * 100).clamp(0, 100);
  }

  IndicatorFilters _availableFilters(
    IndicatorFilters filters,
    Set<StressIndicator> unavailable,
  ) {
    return filters.copyWith(
      airQuality: filters.airQuality &&
          !unavailable.contains(StressIndicator.airQuality),
      populationDensity: filters.populationDensity &&
          !unavailable.contains(StressIndicator.populationDensity),
      noise: filters.noise && !unavailable.contains(StressIndicator.noise),
      traffic:
          filters.traffic && !unavailable.contains(StressIndicator.traffic),
      costOfLiving: filters.costOfLiving &&
          !unavailable.contains(StressIndicator.costOfLiving),
      safety: filters.safety && !unavailable.contains(StressIndicator.safety),
    );
  }
}

class _IndicatorFetchResult {
  const _IndicatorFetchResult({
    required this.indicator,
    required this.value,
    required this.isAvailable,
  });

  final StressIndicator indicator;
  final double value;
  final bool isAvailable;
}
