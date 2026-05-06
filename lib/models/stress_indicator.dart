enum StressIndicator {
  airQuality('Air quality'),
  populationDensity('Population density'),
  noise('Noise'),
  traffic('Traffic'),
  costOfLiving('Cost of living'),
  safety('Safety');

  const StressIndicator(this.label);

  final String label;
}
