import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/loan.dart';
import '../models/saving.dart';

/// Savings & Loans summary shown on the Dashboard. Savings and loans are
/// neither income nor expense, so they live outside the v1 Balance card.
class PositionCard extends StatelessWidget {
  final SavingSummary? savings;
  final LoanSummary? loans;

  const PositionCard({super.key, this.savings, this.loans});

  @override
  Widget build(BuildContext context) {
    if (savings == null && loans == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Position', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            _row(
              context,
              label: 'Total Savings',
              amount: savings?.totalSaved ?? 0,
              color: Colors.green,
              icon: Icons.savings,
            ),
            const Divider(height: 20),
            _row(
              context,
              label: 'I Owe',
              amount: loans?.payableOutstanding ?? 0,
              color: Colors.red,
              icon: Icons.arrow_upward,
            ),
            const Divider(height: 20),
            _row(
              context,
              label: 'Owed To Me',
              amount: loans?.receivableOutstanding ?? 0,
              color: Colors.green,
              icon: Icons.arrow_downward,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        FittedBox(
          child: Text(
            NumberFormat.currency(symbol: 'Rs. ').format(amount),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }
}
