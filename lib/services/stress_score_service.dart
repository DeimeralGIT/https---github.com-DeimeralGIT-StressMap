import '../models/indicator_filters.dart';
import '../models/stress_location.dart';

class StressScoreWeights {
  const StressScoreWeights({
    this.airQualityIndex = 0.25,
    this.populationDensity = 0.20,
    this.noiseLevel = 0.20,
    this.trafficIndex = 0.15,
    this.costOfLivingIndex = 0.10,
    this.safetyIndex = 0.10,
  });

  final double airQualityIndex;
  final double populationDensity;
  final double noiseLevel;
  final double trafficIndex;
  final double costOfLivingIndex;
  final double safetyIndex;
}

class StressScoreService {
  const StressScoreService({this.weights = const StressScoreWeights()});

  final StressScoreWeights weights;

  double calculate(StressLocation location, IndicatorFilters filters) {
    final weightedValues = <({bool enabled, double value, double weight})>[
      (
        enabled: filters.airQuality,
        value: location.airQualityIndex,
        weight: weights.airQualityIndex,
      ),
      (
        enabled: filters.populationDensity,
        value: location.populationDensity,
        weight: weights.populationDensity,
      ),
      (
        enabled: filters.noise,
        value: location.noiseLevel,
        weight: weights.noiseLevel,
      ),
      (
        enabled: filters.traffic,
        value: location.trafficIndex,
        weight: weights.trafficIndex,
      ),
      (
        enabled: filters.costOfLiving,
        value: location.costOfLivingIndex,
        weight: weights.costOfLivingIndex,
      ),
      (
        enabled: filters.safety,
        value: 100 - location.safetyIndex,
        weight: weights.safetyIndex,
      ),
    ];

    final active = weightedValues.where((entry) => entry.enabled).toList();
    if (active.isEmpty) return 0;

    final totalWeight =
        active.fold<double>(0, (sum, item) => sum + item.weight);
    final score = active.fold<double>(
      0,
      (sum, item) => sum + item.value.clamp(0, 100) * item.weight,
    );

    return (score / totalWeight).clamp(0, 100);
  }
}
