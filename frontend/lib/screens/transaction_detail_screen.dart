import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/entry.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import 'entry_form_screen.dart';

class TransactionDetailScreen extends StatelessWidget {
  final Entry entry;
  final ApiService api;

  const TransactionDetailScreen({
    super.key,
    required this.entry,
    required this.api,
  });

  String _catName(int c) =>
      const {0: 'PersonalPayment', 1: 'BillSharing', 2: 'Loan', 3: 'Income'}[c] ??
      'Unknown';

  void _edit(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EntryFormScreen(api: api, entry: entry),
      ),
    );
    if (result == true && context.mounted) {
      Navigator.pop(context, true);
    }
  }

  void _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text('Delete "${entry.description}"?'),
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
        await api.deleteEntry(entry.id);
        if (context.mounted) {
          showSuccessSnackBar(context, 'Deleted successfully', backgroundColor: Colors.red);
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e')),
          );
        }
      }
    }
  }

  void _viewImage(BuildContext context, String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImage(path: path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final isIncome = e.type == 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isIncome
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        child: Icon(
                          isIncome
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color: isIncome ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.description,
                                style:
                                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              '${isIncome ? '+' : '-'}${NumberFormat.currency(symbol: 'Rs. ').format(e.amount)}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isIncome ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                  _detailRow('Date', DateFormat('MMM dd, yyyy').format(e.date)),
                  _detailRow('Category', _catName(e.category)),
                  _detailRow('Type', isIncome ? 'Income' : 'Expense'),
                  _detailRow('Payment Type',
                      const {0: 'Debit', 1: 'Credit'}[e.paymentType] ?? 'Unknown'),
                  _detailRow('Amount',
                      'Rs. ${NumberFormat.decimalPattern().format(e.amount)}'),
                  _detailRow('Created',
                      DateFormat('MMM dd, yyyy – HH:mm').format(e.createdAt)),
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
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const Divider(),
                  _buildScreenshot(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenshot(BuildContext context) {
    final path = entry.screenshotPath;
    if (path == null || path.isEmpty) {
      return Row(
        children: [
          Icon(Icons.image_not_supported, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Text('No screenshot attached',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        ],
      );
    }

    return StatefulBuilder(
      builder: (ctx, setInnerState) => FutureBuilder<bool>(
        future: Permission.manageExternalStorage.isGranted,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
          }

          final granted = snap.data ?? false;
          if (!granted) {
            return Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: GestureDetector(
                onTap: () async {
                  final status = await Permission.manageExternalStorage.request();
                  if (status.isGranted) setInnerState(() {});
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open, color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    Text('Tap to grant file access to view screenshot',
                        style: TextStyle(color: Colors.orange.shade800, fontSize: 13)),
                  ],
                ),
              ),
            );
          }

          final file = File(path);
          return GestureDetector(
            onTap: () => _viewImage(context, path),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                file,
                height: 240,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, error, __) {
                  debugPrint('Image.file error: $error');
                  return Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, color: Colors.grey.shade400),
                        const SizedBox(width: 8),
                        Text('Screenshot unavailable',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String path;

  const FullScreenImage({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: StatefulBuilder(
        builder: (ctx, setInnerState) => FutureBuilder<bool>(
          future: Permission.manageExternalStorage.isGranted,
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54));
            }

            final granted = snap.data ?? false;
            if (!granted) {
              return Center(
                child: GestureDetector(
                  onTap: () async {
                    final status = await Permission.manageExternalStorage.request();
                    if (status.isGranted) setInnerState(() {});
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_open, color: Colors.white54, size: 48),
                      const SizedBox(height: 16),
                      Text('Tap to grant file access',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                    ],
                  ),
                ),
              );
            }

            return Center(
              child: InteractiveViewer(
                child: Image.file(
                  File(path),
                  fit: BoxFit.contain,
                  errorBuilder: (_, error, __) {
                    debugPrint('FullScreenImage error: $error');
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                        const SizedBox(height: 16),
                        Text('Screenshot unavailable',
                            style: TextStyle(color: Colors.grey.shade400)),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}