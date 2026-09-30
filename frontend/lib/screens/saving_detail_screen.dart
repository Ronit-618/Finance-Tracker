import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/saving.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import 'entry_form_screen.dart';
import 'transaction_detail_screen.dart' show FullScreenImage;
import '../widgets/record_screenshot.dart';

class SavingDetailScreen extends ConsumerWidget {
  final Saving saving;
  final ApiService api;

  const SavingDetailScreen({
    super.key,
    required this.saving,
    required this.api,
  });

  Future<void> _edit(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EntryFormScreen(api: api, saving: saving),
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
        title: const Text('Delete Saving'),
        content: Text('Delete "${saving.description}"?'),
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
        await api.deleteSaving(saving.id);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saving Details'),
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
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: const Icon(Icons.savings, color: Colors.green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          saving.description,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          NumberFormat.currency(symbol: 'Rs. ')
                              .format(saving.amount),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
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
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const Divider(),
                  RecordDetailRow(
                    label: 'Date',
                    value: formatRecordDate(context, ref, saving.date,
                        saving.bsDate),
                  ),
                  RecordDetailRow(label: 'Category', value: saving.category),
                  RecordDetailRow(
                    label: 'Amount',
                    value:
                        'Rs. ${NumberFormat.decimalPattern().format(saving.amount)}',
                  ),
                  RecordDetailRow(
                    label: 'Created',
                    value: DateFormat('MMM dd, yyyy – HH:mm')
                        .format(saving.createdAt),
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
                  const Text('Screenshot',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const Divider(),
                  RecordScreenshot(
                    path: saving.screenshotPath,
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
