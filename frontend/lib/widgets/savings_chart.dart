import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/entry_group.dart';

class SavingsChart extends StatelessWidget {
  final List<EntryGroup> groups;

  const SavingsChart({super.key, required this.groups});

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    final recent = groups.takeLast(6).toList();

    if (recent.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Savings', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              const Center(child: Text('No data yet')),
            ],
          ),
        ),
      );
    }

    final balances = recent.map((g) => g.balance).toList();
    final maxVal = balances.fold<double>(0, (s, v) => v.abs() > s ? v.abs() : s);
    final minVal = -maxVal;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Savings', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  minY: minVal * 1.2,
                  maxY: maxVal * 1.2,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= recent.length) return const SizedBox.shrink();
                          final parts = recent[i].period.split('-');
                          final monthIdx = int.tryParse(parts[1]) ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              monthIdx > 0 && monthIdx <= 12 ? _months[monthIdx] : recent[i].period,
                              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            NumberFormat.compact().format(value),
                            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxVal * 1.2 / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(recent.length, (i) {
                    final balance = recent[i].balance;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: balance,
                          color: balance >= 0 ? Colors.green : Colors.red,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _ListTakeLast<T> on List<T> {
  List<T> takeLast(int n) => n >= length ? this : sublist(length - n);
}
