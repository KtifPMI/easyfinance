import 'package:flutter/material.dart';

class SimpleBarChart extends StatelessWidget {
  final List<({String label, double value, Color color})> slices;
  final double height;
  final bool showPercentages;

  const SimpleBarChart({
    super.key,
    required this.slices,
    this.height = 180,
    this.showPercentages = true,
  });

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) return const SizedBox.shrink();
    final maxVal = slices.fold<double>(0, (m, s) => s.value > m ? s.value : m);
    final total = slices.fold<double>(0, (s, e) => s + e.value);

    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: slices.map((s) {
              final fraction = maxVal > 0 ? s.value / maxVal : 0.0;
              final barHeight = fraction * height.clamp(40, double.infinity);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (showPercentages && total > 0)
                        Text('${(s.value / total * 100).round()}%', style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Flexible(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: s.color,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(s.label, style: TextStyle(fontSize: 9, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
