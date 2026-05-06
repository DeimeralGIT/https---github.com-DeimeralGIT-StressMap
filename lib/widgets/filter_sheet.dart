import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/indicator_filters.dart';
import '../providers/stress_map_controller.dart';

class FilterSheet extends StatelessWidget {
  const FilterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StressMapController>();
    final filters = controller.filters;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('filters.title'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('filters.description'),
                style: const TextStyle(color: Color(0xFF9FAABC)),
              ),
              const SizedBox(height: 18),
              _FilterSwitch(
                label: context.tr('filters.airQuality'),
                icon: Icons.air_rounded,
                value: filters.airQuality,
                onChanged: (value) => _update(
                  context,
                  filters.copyWith(airQuality: value),
                ),
              ),
              _FilterSwitch(
                label: context.tr('filters.populationDensity'),
                icon: Icons.location_city_rounded,
                value: filters.populationDensity,
                onChanged: (value) => _update(
                  context,
                  filters.copyWith(populationDensity: value),
                ),
              ),
              _FilterSwitch(
                label: context.tr('filters.noise'),
                icon: Icons.graphic_eq_rounded,
                value: filters.noise,
                onChanged: (value) =>
                    _update(context, filters.copyWith(noise: value)),
              ),
              _FilterSwitch(
                label: context.tr('filters.traffic'),
                icon: Icons.traffic_rounded,
                value: filters.traffic,
                onChanged: (value) =>
                    _update(context, filters.copyWith(traffic: value)),
              ),
              _FilterSwitch(
                label: context.tr('filters.costOfLiving'),
                icon: Icons.payments_rounded,
                value: filters.costOfLiving,
                onChanged: (value) => _update(
                  context,
                  filters.copyWith(costOfLiving: value),
                ),
              ),
              _FilterSwitch(
                label: context.tr('filters.safety'),
                icon: Icons.shield_rounded,
                value: filters.safety,
                onChanged: (value) =>
                    _update(context, filters.copyWith(safety: value)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _update(BuildContext context, IndicatorFilters filters) {
    context.read<StressMapController>().setFilters(filters);
  }
}

class _FilterSwitch extends StatelessWidget {
  const _FilterSwitch({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF121A26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF35D07F), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
