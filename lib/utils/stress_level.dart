import 'package:flutter/material.dart';

enum StressLevel {
  low('Low'),
  medium('Medium'),
  high('High'),
  critical('Critical');

  const StressLevel(this.label);

  final String label;
}

StressLevel stressLevelForScore(double score) {
  if (score >= 78) return StressLevel.critical;
  if (score >= 58) return StressLevel.high;
  if (score >= 34) return StressLevel.medium;
  return StressLevel.low;
}

Color stressColorForScore(double score) {
  final level = stressLevelForScore(score);
  return switch (level) {
    StressLevel.low => const Color(0xFF35D07F),
    StressLevel.medium => const Color(0xFFFFD166),
    StressLevel.high => const Color(0xFFFF8A3D),
    StressLevel.critical => const Color(0xFFFF4D5E),
  };
}
