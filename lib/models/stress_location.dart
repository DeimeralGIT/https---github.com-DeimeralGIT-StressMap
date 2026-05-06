import 'stress_indicator.dart';

class StressLocation {
  const StressLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.populationDensity,
    required this.airQualityIndex,
    required this.noiseLevel,
    required this.costOfLivingIndex,
    required this.trafficIndex,
    required this.safetyIndex,
    required this.stressScore,
    this.unavailableIndicators = const {},
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double populationDensity;
  final double airQualityIndex;
  final double noiseLevel;
  final double costOfLivingIndex;
  final double trafficIndex;
  final double safetyIndex;
  final double stressScore;
  final Set<StressIndicator> unavailableIndicators;

  bool isIndicatorAvailable(StressIndicator indicator) {
    return !unavailableIndicators.contains(indicator);
  }

  StressLocation copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? populationDensity,
    double? airQualityIndex,
    double? noiseLevel,
    double? costOfLivingIndex,
    double? trafficIndex,
    double? safetyIndex,
    double? stressScore,
    Set<StressIndicator>? unavailableIndicators,
  }) {
    return StressLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      populationDensity: populationDensity ?? this.populationDensity,
      airQualityIndex: airQualityIndex ?? this.airQualityIndex,
      noiseLevel: noiseLevel ?? this.noiseLevel,
      costOfLivingIndex: costOfLivingIndex ?? this.costOfLivingIndex,
      trafficIndex: trafficIndex ?? this.trafficIndex,
      safetyIndex: safetyIndex ?? this.safetyIndex,
      stressScore: stressScore ?? this.stressScore,
      unavailableIndicators:
          unavailableIndicators ?? this.unavailableIndicators,
    );
  }
}
