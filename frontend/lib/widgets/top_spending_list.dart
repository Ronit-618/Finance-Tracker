import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/category_total.dart';

class TopSpendingList extends StatelessWidget {
  final List<CategoryTotal> data;

  const TopSpendingList({super.key, required this.data});

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
              Text('Top Spending Categories',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              const Center(child: Text('No data yet')),
            ],
          ),
        ),
      );
    }

    final top5 = data.take(5).toList();
    final maxAmount = top5.first.total;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Spending Categories',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ...List.generate(top5.length, (i) {
              final item = top5[i];
              final fraction = maxAmount > 0 ? item.total / maxAmount : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.category,
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text(
                          NumberFormat.currency(symbol: 'Rs. ').format(item.total),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: fraction,
                        backgroundColor: Colors.grey.shade200,
                        color: Colors.red.shade400,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
