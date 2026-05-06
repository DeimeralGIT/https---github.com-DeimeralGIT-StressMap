import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stress_indicator.dart';
import '../models/stress_location.dart';
import '../providers/stress_map_controller.dart';
import '../utils/stress_level.dart';

class LocationDetailCard extends StatelessWidget {
  const LocationDetailCard({
    super.key,
    required this.location,
    this.compact = false,
  });

  final StressLocation location;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scoreColor = stressColorForScore(location.stressScore);
    final level = stressLevelForScore(location.stressScore);
    final filters = context.watch<StressMapController>().filters;

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: const Color(0xF20B111A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 18 : 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${location.latitude.toStringAsFixed(3)}, ${location.longitude.toStringAsFixed(3)}',
                      style: const TextStyle(
                        color: Color(0xFF99A7B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scoreColor.withValues(alpha: 0.42)),
                ),
                child: Column(
                  children: [
                    Text(
                      location.stressScore.round().toString(),
                      style: TextStyle(
                        color: scoreColor,
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 20 : 22,
                      ),
                    ),
                    Text(
                      _levelLabel(context, level),
                      style: const TextStyle(
                        color: Color(0xFFDCE5EF),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 16),
          if (filters.airQuality)
            _MetricBar(
              label: context.tr('filters.airQuality'),
              value: location.airQualityIndex,
              color: const Color(0xFF80B9FF),
              compact: compact,
              isAvailable: location.isIndicatorAvailable(
                StressIndicator.airQuality,
              ),
            ),
          if (filters.populationDensity)
            _MetricBar(
              label: context.tr('filters.populationDensity'),
              value: location.populationDensity,
              color: const Color(0xFF35D07F),
              compact: compact,
              isAvailable: location.isIndicatorAvailable(
                StressIndicator.populationDensity,
              ),
            ),
          if (filters.noise)
            _MetricBar(
              label: context.tr('filters.noise'),
              value: location.noiseLevel,
              color: const Color(0xFFFFD166),
              compact: compact,
              isAvailable: location.isIndicatorAvailable(StressIndicator.noise),
            ),
          if (filters.traffic)
            _MetricBar(
              label: context.tr('filters.traffic'),
              value: location.trafficIndex,
              color: const Color(0xFFFF8A3D),
              compact: compact,
              isAvailable:
                  location.isIndicatorAvailable(StressIndicator.traffic),
            ),
          if (filters.costOfLiving)
            _MetricBar(
              label: context.tr('filters.costOfLiving'),
              value: location.costOfLivingIndex,
              color: const Color(0xFFE06CFF),
              compact: compact,
              isAvailable: location.isIndicatorAvailable(
                StressIndicator.costOfLiving,
              ),
            ),
          if (filters.safety)
            _MetricBar(
              label: context.tr('filters.safety'),
              value: location.safetyIndex,
              color: const Color(0xFF7BE0D8),
              compact: compact,
              isAvailable: location.isIndicatorAvailable(StressIndicator.safety),
            ),
        ],
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.label,
    required this.value,
    required this.color,
    required this.compact,
    required this.isAvailable,
  });

  final String label;
  final double value;
  final Color color;
  final bool compact;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    final normalized = (value / 100).clamp(0.0, 1.0);
    final labelStyle = const TextStyle(color: Color(0xFFC4CEDA), fontSize: 12);

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ),
              if (isAvailable)
                Text(
                  value.round().toString(),
                  style: const TextStyle(
                    color: Color(0xFFEAF1F8),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFFF6B7A),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('details.unavailable'),
                      style: const TextStyle(
                        color: Color(0xFFFF9AA5),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          SizedBox(height: compact ? 4 : 5),
          if (isAvailable)
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: normalized,
                minHeight: compact ? 6 : 7,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                color: color,
              ),
            )
          else
            Container(
              height: compact ? 22 : 24,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D5E).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFFFF4D5E).withValues(alpha: 0.22),
                ),
              ),
              child: Text(
                context.tr('details.fallback'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFFB8C0),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _levelLabel(BuildContext context, StressLevel level) {
  return switch (level) {
    StressLevel.low => context.tr('legend.low'),
    StressLevel.medium => context.tr('legend.medium'),
    StressLevel.high => context.tr('legend.high'),
    StressLevel.critical => context.tr('legend.critical'),
  };
}
