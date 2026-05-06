import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/app_logger.dart';

class AirQualityService {
  AirQualityService({http.Client? client}) : _client = client ?? http.Client();

  static const apiKey = 'YOUR_AIR_QUALITY_API_KEY';

  final http.Client _client;
  final _cache = <String, double>{};
  final _inFlight = <String, Future<double>>{};

  void clearCache() {
    _cache.clear();
  }

  Future<double> fetchAirQualityIndex({
    required double latitude,
    required double longitude,
  }) async {
    final cacheKey = _cacheKey(latitude, longitude);
    final cached = _cache[cacheKey];
    if (cached != null) {
      AppLogger.info(
        'AirQualityService',
        'Cache hit for $cacheKey with AQI ${cached.toStringAsFixed(1)}',
      );
      return cached;
    }

    final inFlight = _inFlight[cacheKey];
    if (inFlight != null) {
      AppLogger.info(
        'AirQualityService',
        'Joining in-flight AQI request for $cacheKey',
      );
      return inFlight;
    }

    final request = _fetchAirQualityIndex(cacheKey, latitude, longitude);
    _inFlight[cacheKey] = request;

    try {
      return await request;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  Future<double> _fetchAirQualityIndex(
    String cacheKey,
    double latitude,
    double longitude,
  ) async {

    AppLogger.info(
      'AirQualityService',
      'Requesting AQI for $cacheKey',
    );

    final uri = Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
      'latitude': latitude.toStringAsFixed(5),
      'longitude': longitude.toStringAsFixed(5),
      'current': 'us_aqi',
      'hourly': 'us_aqi',
      'forecast_days': '1',
      'timezone': 'auto',
    });

    final response =
        await _client.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      AppLogger.error(
        'AirQualityService',
        'Air quality request failed with status ${response.statusCode}',
      );
      throw Exception('Air quality request failed: ${response.statusCode}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final current = payload['current'] as Map<String, dynamic>?;
    final currentAqi = (current?['us_aqi'] as num?)?.toDouble();
    final hourly = payload['hourly'] as Map<String, dynamic>?;
    final values = (hourly?['us_aqi'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((value) => value.toDouble())
        .toList();
    final latest = currentAqi ?? (values.isNotEmpty ? values.last : null);
    if (latest == null) {
      AppLogger.warning(
        'AirQualityService',
        'No AQI payload values available for $cacheKey',
      );
      throw Exception('Air quality data unavailable.');
    }

    final score = latest.clamp(0, 100).toDouble();
    AppLogger.info(
      'AirQualityService',
      'AQI resolved for $cacheKey: raw=${latest.toStringAsFixed(1)} score=${score.toStringAsFixed(1)}',
    );
    _cache[cacheKey] = score;
    if (_cache.length > 80) {
      _cache.remove(_cache.keys.first);
    }
    return score;
  }

  String _cacheKey(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(1)}:${longitude.toStringAsFixed(1)}';
  }
}
