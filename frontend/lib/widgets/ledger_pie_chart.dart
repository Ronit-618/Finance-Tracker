import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/ledger_item.dart';

/// Breakdown of where the money sits: income earned, expenses paid, savings set
/// aside and loan principal. Replaces the old income-vs-expense bar chart.
class LedgerPieChart extends StatelessWidget {
  final LedgerSummary summary;

  const LedgerPieChart({super.key, required this.summary});

  static const _colors = [
    Color(0xFF2ECC71),
    Color(0xFFE74C3C),
    Color(0xFF3498DB),
    Color(0xFF9B59B6),
  ];

  @override
  Widget build(BuildContext context) {
    final slices = <({String label, double value})>[
      (label: 'Income', value: summary.totalIncome),
      (label: 'Expense', value: summary.totalExpense),
      (label: 'Savings', value: summary.totalSaved),
      (label: 'Loan', value: summary.totalLoan),
    ];

    final total = slices.fold<double>(0, (s, e) => s + e.value);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Money Breakdown',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (total <= 0)
              const Center(child: Text('No data yet'))
            else ...[
              Center(
                child: SizedBox(
                  height: 180,
                  width: 180,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: List.generate(slices.length, (i) {
                        final pct = slices[i].value / total;
                        return PieChartSectionData(
                          color: _colors[i % _colors.length],
                          value: slices[i].value,
                          title: '${(pct * 100).toStringAsFixed(0)}%',
                          radius: 48,
                          titleStyle: const TextStyle(
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
                  children: List.generate(slices.length, (i) {
                    final pct = slices[i].value / total;
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
                          '${slices[i].label} (${(pct * 100).toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
