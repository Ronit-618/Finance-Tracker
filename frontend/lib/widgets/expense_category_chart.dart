import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/category_total.dart';

class ExpenseCategoryChart extends StatelessWidget {
  final List<CategoryTotal> data;

  const ExpenseCategoryChart({super.key, required this.data});

  static const _colors = [
    Color(0xFFE74C3C),
    Color(0xFF3498DB),
    Color(0xFF2ECC71),
    Color(0xFFF39C12),
  ];

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Expense by Category',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              const Center(child: Text('No data yet')),
            ],
          ),
        ),
      );
    }

    final total = data.fold<double>(0, (s, e) => s + e.total);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expense by Category',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                height: 160,
                width: 160,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 36,
                    sections: List.generate(data.length, (i) {
                      final pct = data[i].total / total;
                      return PieChartSectionData(
                        color: _colors[i % _colors.length],
                        value: data[i].total,
                        title: '${(pct * 100).toStringAsFixed(0)}%',
                        radius: 44,
                        titleStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: List.generate(data.length, (i) {
                  final pct = data[i].total / total;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _colors[i % _colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${data[i].category} (${(pct * 100).toStringAsFixed(1)}%)',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
