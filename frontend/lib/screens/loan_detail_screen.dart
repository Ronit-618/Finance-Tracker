import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/loan.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import 'entry_form_screen.dart';
import 'transaction_detail_screen.dart' show FullScreenImage;
import '../widgets/record_screenshot.dart';

class LoanDetailScreen extends ConsumerWidget {
  final Loan loan;
  final ApiService api;

  const LoanDetailScreen({
    super.key,
    required this.loan,
    required this.api,
  });

  Future<void> _edit(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EntryFormScreen(api: api, loan: loan),
      ),
    );
    if (result == true && context.mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Loan'),
        content: Text('Delete "${loan.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await api.deleteLoan(loan.id);
        if (context.mounted) {
          showSuccessSnackBar(context, 'Deleted successfully',
              backgroundColor: Colors.red);
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(friendlyError(e))));
        }
      }
    }
  }

  Future<void> _toggleSettled(BuildContext context) async {
    try {
      await api.toggleLoanSettled(loan.id);
      if (context.mounted) {
        showSuccessSnackBar(
          context,
          loan.isSettled ? 'Marked as open' : 'Marked as settled',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = loan.isBorrowed ? Colors.red : Colors.green;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            onPressed: () => _edit(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete',
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: loan.isBorrowed
                        ? Theme.of(context).colorScheme.errorContainer
                        : Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      loan.isBorrowed ? Icons.arrow_upward : Icons.arrow_downward,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loan.description,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            decoration:
                                loan.isSettled ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          NumberFormat.currency(symbol: 'Rs. ').format(loan.amount),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Details',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const Divider(),
                  RecordDetailRow(
                    label: 'Direction',
                    value: loan.isBorrowed ? 'Borrowed (I owe)' : 'Lent (owed to me)',
                  ),
                  RecordDetailRow(
                    label: loan.isBorrowed ? 'From' : 'To',
                    value: loan.person ?? '—',
                  ),
                  RecordDetailRow(
                    label: 'Status',
                    value: loan.isSettled ? 'Settled' : 'Open',
                  ),
                  RecordDetailRow(
                    label: 'Date',
                    value: formatRecordDate(context, ref, loan.date, loan.bsDate),
                  ),
                  RecordDetailRow(label: 'Category', value: loan.category),
                  if (loan.settledDate != null)
                    RecordDetailRow(
                      label: 'Settled on',
                      value: DateFormat('MMM dd, yyyy').format(loan.settledDate!),
                    ),
                  RecordDetailRow(
                    label: 'Created',
                    value: DateFormat('MMM dd, yyyy – HH:mm').format(loan.createdAt),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: loan.isSettled ? Colors.orange : Colors.green,
            ),
            icon: Icon(loan.isSettled ? Icons.undo : Icons.check),
            label: Text(loan.isSettled ? 'Mark as Open' : 'Mark as Settled'),
            onPressed: () => _toggleSettled(context),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Screenshot',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const Divider(),
                  RecordScreenshot(
                    path: loan.screenshotPath,
                    onView: (p) => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FullScreenImage(path: p),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
