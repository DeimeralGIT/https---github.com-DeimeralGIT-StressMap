import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/discovered_place.dart';
import '../models/map_bounds.dart';
import '../utils/app_logger.dart';

class PlaceDiscoveryService {
  PlaceDiscoveryService({http.Client? client})
      : _client = client ?? http.Client();

  static final _endpoint = Uri.parse('https://overpass-api.de/api/interpreter');
  static const _maxPlaces = 6;

  final http.Client _client;
  final _cache = <String, List<DiscoveredPlace>>{};

  void clearCache() {
    _cache.clear();
  }

  Future<List<DiscoveredPlace>> fetchPlacesInBounds(MapBounds bounds) async {
    if (bounds.isTooBroadForPlaceLookup) {
      AppLogger.warning(
        'PlaceDiscoveryService',
        'Skipping place lookup for broad bounds ${bounds.north.toStringAsFixed(2)},${bounds.south.toStringAsFixed(2)},${bounds.east.toStringAsFixed(2)},${bounds.west.toStringAsFixed(2)}',
      );
      return const [];
    }
    final cacheKey = _cacheKeyForBounds(bounds);
    final cached = _cache[cacheKey];
    if (cached != null) {
      AppLogger.info(
        'PlaceDiscoveryService',
        'Cache hit for bounds $cacheKey with ${cached.length} places.',
      );
      return cached;
    }

    AppLogger.info(
      'PlaceDiscoveryService',
      'Requesting places for bounds $cacheKey',
    );

    final query = '''
[out:json][timeout:10];
(
  node["place"~"^(city|town|village|hamlet)\$"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
);
out tags center 40;
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
      throw Exception('Overpass request failed: ${response.statusCode}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = (payload['elements'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();

    final places = elements
        .map(_placeFromElement)
        .whereType<DiscoveredPlace>()
        .toList()
      ..sort(_sortPlaces);

    final seen = <String>{};
    final discovered = [
      for (final place in places)
        if (seen.add(
            '${place.name}-${place.latitude.toStringAsFixed(2)}-${place.longitude.toStringAsFixed(2)}'))
          place,
    ].take(_maxPlaces).toList();

    _cache[cacheKey] = discovered;
    if (_cache.length > 30) {
      _cache.remove(_cache.keys.first);
    }
    AppLogger.info(
      'PlaceDiscoveryService',
      'Resolved ${discovered.length} unique places for bounds $cacheKey',
    );
    return discovered;
  }

  DiscoveredPlace? _placeFromElement(Map<String, dynamic> element) {
    final tags = element['tags'] as Map<String, dynamic>? ?? const {};
    final name = tags['name']?.toString().trim();
    final placeType = tags['place']?.toString() ?? 'place';
    final latitude = (element['lat'] as num?)?.toDouble() ??
        ((element['center'] as Map<String, dynamic>?)?['lat'] as num?)
            ?.toDouble();
    final longitude = (element['lon'] as num?)?.toDouble() ??
        ((element['center'] as Map<String, dynamic>?)?['lon'] as num?)
            ?.toDouble();

    if (name == null || name.isEmpty || latitude == null || longitude == null) {
      return null;
    }
    if (!latitude.isFinite || !longitude.isFinite) {
      AppLogger.warning(
        'PlaceDiscoveryService',
        'Dropping place with non-finite coordinates: $name',
      );
      return null;
    }

    return DiscoveredPlace(
      id: '${element['type']}-${element['id']}',
      name: name,
      latitude: latitude,
      longitude: longitude,
      placeType: placeType,
      population: _parsePopulation(tags['population']?.toString()),
    );
  }

  int? _parsePopulation(String? value) {
    if (value == null) return null;
    final normalized = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) return null;
    return int.tryParse(normalized);
  }

  int _sortPlaces(DiscoveredPlace a, DiscoveredPlace b) {
    final populationCompare = (b.population ?? 0).compareTo(a.population ?? 0);
    if (populationCompare != 0) return populationCompare;
    return _placeRank(a.placeType).compareTo(_placeRank(b.placeType));
  }

  int _placeRank(String type) {
    return switch (type) {
      'city' => 0,
      'town' => 1,
      'village' => 2,
      _ => 3,
    };
  }

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
