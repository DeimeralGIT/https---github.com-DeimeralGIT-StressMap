class PopulationService {
  static const apiKey = 'YOUR_POPULATION_DATA_API_KEY';

  Future<double> fetchPopulationDensityScore({
    required double latitude,
    required double longitude,
  }) async {
    // Connect WorldPop, Census, city open data, or a hosted tileset here.
    throw UnimplementedError('Population API not connected yet.');
  }
}
