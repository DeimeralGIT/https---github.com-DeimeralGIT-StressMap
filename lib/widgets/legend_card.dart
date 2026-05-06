import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class LegendCard extends StatelessWidget {
  const LegendCard({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: compact ? 178 : 210,
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          color: const Color(0xE60B111A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('legend.title'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            SizedBox(height: compact ? 8 : 10),
            _LegendRow(
                color: const Color(0xFF35D07F), label: context.tr('legend.low')),
            _LegendRow(
              color: const Color(0xFFFFD166),
              label: context.tr('legend.medium'),
            ),
            _LegendRow(
                color: const Color(0xFFFF8A3D), label: context.tr('legend.high')),
            _LegendRow(
              color: const Color(0xFFFF4D5E),
              label: context.tr('legend.critical'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Text(label, style: const TextStyle(color: Color(0xFFDCE5EF))),
        ],
      ),
    );
  }
}
