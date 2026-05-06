import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../models/discovered_place.dart';
import '../models/map_bounds.dart';
import '../models/urban_signal_profile.dart';
import '../utils/app_logger.dart';

class UrbanSignalsService {
  UrbanSignalsService({http.Client? client})
      : _client = client ?? http.Client();

  static final _endpoint = Uri.parse('https://overpass-api.de/api/interpreter');

  final http.Client _client;
  final _cache = <String, List<_UrbanFeature>>{};
  static const _signalRadiusKm = 6.0;

  void clearCache() {
    _cache.clear();
  }

  Future<Map<String, UrbanSignalProfile>> fetchProfiles({
    required MapBounds bounds,
    required List<DiscoveredPlace> places,
  }) async {
    if (places.isEmpty) {
      return const {};
    }

    AppLogger.info(
      'UrbanSignalsService',
      'Fetching signal profiles for ${places.length} places.',
    );
    final profiles = <String, UrbanSignalProfile>{};
    for (final place in places) {
      try {
        final features = await _fetchFeatures(_boundsAroundPlace(place));
        profiles[place.id] = _profileForPlace(place, features);
        AppLogger.info(
          'UrbanSignalsService',
          'Profile computed for ${place.name} using ${features.length} nearby features.',
        );
      } catch (error) {
        AppLogger.warning(
          'UrbanSignalsService',
          'Skipping urban profile for ${place.name} after fetch failure: $error',
        );
      }
    }

    return profiles;
  }

  MapBounds _boundsAroundPlace(DiscoveredPlace place) {
    const kmPerDegreeLat = 111.0;
    final latDelta = _signalRadiusKm / kmPerDegreeLat;
    final cosLatitude = math.cos(_radians(place.latitude.abs())).abs();
    final safeCosLatitude = cosLatitude < 0.15 ? 0.15 : cosLatitude;
    final lngDelta = _signalRadiusKm / (kmPerDegreeLat * safeCosLatitude);

    return MapBounds(
      north: (place.latitude + latDelta).clamp(-85.0, 85.0),
      south: (place.latitude - latDelta).clamp(-85.0, 85.0),
      east: (place.longitude + lngDelta).clamp(-180.0, 180.0),
      west: (place.longitude - lngDelta).clamp(-180.0, 180.0),
    );
  }

  Future<List<_UrbanFeature>> _fetchFeatures(MapBounds bounds) async {
    final cacheKey = _cacheKeyForBounds(bounds);
    final cached = _cache[cacheKey];
    if (cached != null) {
      AppLogger.info(
        'UrbanSignalsService',
        'Feature cache hit for $cacheKey (${cached.length} features).',
      );
      return cached;
    }

    AppLogger.info(
      'UrbanSignalsService',
      'Requesting urban features for $cacheKey',
    );

    final query = '''
[out:json][timeout:10];
(
  way["highway"~"^(motorway|trunk|primary|secondary|tertiary)\$"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
  node["highway"="traffic_signals"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
  way["railway"~"^(rail|tram|subway)\$"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
  node["railway"~"^(station|halt|tram_stop)\$"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
  way["landuse"="industrial"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
  node["aeroway"~"^(aerodrome|helipad)\$"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
  node["amenity"~"^(police|fire_station|hospital|clinic|doctors)\$"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
  way["amenity"~"^(police|fire_station|hospital|clinic|doctors)\$"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
  node["shop"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
  node["tourism"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
  node["amenity"~"^(restaurant|cafe|bar|pub|bank|marketplace|cinema|theatre)\$"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
);
out tags center 260;
''';

    final response = await _client.post(
      _endpoint,
      headers: const {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'User-Agent': 'PopulationStressMap/1.0 portfolio MVP',
      },
      body: {'data': query},
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Urban signals request failed: ${response.statusCode}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final features = (payload['elements'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_featureFromElement)
        .whereType<_UrbanFeature>()
        .toList();

    _cache[cacheKey] = features;
    if (_cache.length > 30) {
      _cache.remove(_cache.keys.first);
    }
    AppLogger.info(
      'UrbanSignalsService',
      'Fetched ${features.length} urban features for $cacheKey',
    );
    return features;
  }

  _UrbanFeature? _featureFromElement(Map<String, dynamic> element) {
    final tags = element['tags'] as Map<String, dynamic>? ?? const {};
    final latitude = (element['lat'] as num?)?.toDouble() ??
        ((element['center'] as Map<String, dynamic>?)?['lat'] as num?)
            ?.toDouble();
    final longitude = (element['lon'] as num?)?.toDouble() ??
        ((element['center'] as Map<String, dynamic>?)?['lon'] as num?)
            ?.toDouble();
    if (latitude == null || longitude == null) return null;
    if (!latitude.isFinite || !longitude.isFinite) return null;

    return _UrbanFeature(
      latitude: latitude,
      longitude: longitude,
      category: _categoryForTags(tags),
    );
  }

  _UrbanSignalCategory _categoryForTags(Map<String, dynamic> tags) {
    if (tags.containsKey('highway')) {
      return tags['highway'] == 'traffic_signals'
          ? _UrbanSignalCategory.trafficSignal
          : _UrbanSignalCategory.majorRoad;
    }
    if (tags.containsKey('railway')) return _UrbanSignalCategory.rail;
    if (tags['landuse'] == 'industrial' || tags.containsKey('aeroway')) {
      return _UrbanSignalCategory.noiseSource;
    }
    if (tags.containsKey('shop') ||
        tags.containsKey('tourism') ||
        _commercialAmenities.contains(tags['amenity'])) {
      return _UrbanSignalCategory.commercial;
    }
    if (_safetyAmenities.contains(tags['amenity'])) {
      return _UrbanSignalCategory.safetyAmenity;
    }
    return _UrbanSignalCategory.commercial;
  }

  UrbanSignalProfile _profileForPlace(
    DiscoveredPlace place,
    List<_UrbanFeature> features,
  ) {
    var roadScore = 0.0;
    var signalScore = 0.0;
    var railScore = 0.0;
    var noiseSourceScore = 0.0;
    var commercialScore = 0.0;
    var safetyAmenityScore = 0.0;

    for (final feature in features) {
      final distanceKm = _distanceKm(
        place.latitude,
        place.longitude,
        feature.latitude,
        feature.longitude,
      );
      if (distanceKm > _signalRadiusKm) continue;

      final proximity =
          (1 - distanceKm / _signalRadiusKm).clamp(0, 1).toDouble();
      final weighted = proximity * proximity;

      switch (feature.category) {
        case _UrbanSignalCategory.majorRoad:
          roadScore += weighted;
        case _UrbanSignalCategory.trafficSignal:
          signalScore += weighted;
        case _UrbanSignalCategory.rail:
          railScore += weighted;
        case _UrbanSignalCategory.noiseSource:
          noiseSourceScore += weighted;
        case _UrbanSignalCategory.commercial:
          commercialScore += weighted;
        case _UrbanSignalCategory.safetyAmenity:
          safetyAmenityScore += weighted;
      }
    }

    final placeWeight = switch (place.placeType) {
      'city' => 14.0,
      'town' => 8.0,
      'village' => 4.0,
      _ => 2.0,
    };
    final populationWeight = _populationCostSignal(place.population);

    final traffic = _score(roadScore * 8 + signalScore * 7 + placeWeight);
    final noise = _score(
      roadScore * 5 + railScore * 7 + noiseSourceScore * 11 + traffic * 0.18,
    );
    final commercialPressure = _score(commercialScore * 10);
    final cost = _score(
      _costBaseForPlaceType(place.placeType) * 0.55 +
          populationWeight * 0.30 +
          commercialPressure * 0.15,
    );
    final safety =
        (45 + safetyAmenityScore * 14 - traffic * 0.10).clamp(0, 100);

    return UrbanSignalProfile(
      noiseLevel: noise,
      trafficIndex: traffic,
      costOfLivingIndex: cost,
      safetyIndex: safety.toDouble(),
    );
  }

  double _score(double raw) => raw.clamp(0, 100).toDouble();

  double _populationCostSignal(int? population) {
    if (population == null || population <= 0) return 42;
    final normalized =
        (math.log(population.clamp(1, 12000000)) / math.log(12000000)) * 100;
    return normalized.clamp(0, 100).toDouble();
  }

  double _costBaseForPlaceType(String placeType) {
    return switch (placeType) {
      'city' => 78,
      'town' => 62,
      'village' => 45,
      'hamlet' => 34,
      _ => 50,
    };
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _radians(double degrees) => degrees * math.pi / 180;

  String _cacheKeyForBounds(MapBounds bounds) {
    String bucket(double value) => value.toStringAsFixed(2);
    return [
      bucket(bounds.north),
      bucket(bounds.south),
      bucket(bounds.east),
      bucket(bounds.west),
    ].join(':');
  }
}

const _commercialAmenities = {
  'restaurant',
  'cafe',
  'bar',
  'pub',
  'bank',
  'marketplace',
  'cinema',
  'theatre',
};

const _safetyAmenities = {
  'police',
  'fire_station',
  'hospital',
  'clinic',
  'doctors',
};

enum _UrbanSignalCategory {
  majorRoad,
  trafficSignal,
  rail,
  noiseSource,
  commercial,
  safetyAmenity,
}

class _UrbanFeature {
  const _UrbanFeature({
    required this.latitude,
    required this.longitude,
    required this.category,
  });

  final double latitude;
  final double longitude;
  final _UrbanSignalCategory category;
}
