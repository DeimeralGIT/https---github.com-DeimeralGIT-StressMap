class IndicatorFilters {
  const IndicatorFilters({
    this.airQuality = true,
    this.populationDensity = true,
    this.noise = true,
    this.traffic = true,
    this.costOfLiving = true,
    this.safety = true,
  });

  final bool airQuality;
  final bool populationDensity;
  final bool noise;
  final bool traffic;
  final bool costOfLiving;
  final bool safety;

  IndicatorFilters copyWith({
    bool? airQuality,
    bool? populationDensity,
    bool? noise,
    bool? traffic,
    bool? costOfLiving,
    bool? safety,
  }) {
    return IndicatorFilters(
      airQuality: airQuality ?? this.airQuality,
      populationDensity: populationDensity ?? this.populationDensity,
      noise: noise ?? this.noise,
      traffic: traffic ?? this.traffic,
      costOfLiving: costOfLiving ?? this.costOfLiving,
      safety: safety ?? this.safety,
    );
  }
}
