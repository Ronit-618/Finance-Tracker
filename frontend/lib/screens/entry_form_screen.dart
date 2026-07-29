import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/entry.dart';
import '../services/api_service.dart';
import '../services/screenshot_service.dart';
import '../models/pending_store.dart';
import '../utils/snackbar_helper.dart';

class EntryFormScreen extends StatefulWidget {
  final ApiService api;
  final Entry? entry;
  final dynamic pendingCapture;

  const EntryFormScreen({
    super.key,
    required this.api,
    this.entry,
    this.pendingCapture,
  });

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  late DateTime _date;
  late int _type;
late int _category;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.entry!;
      _descCtrl.text = e.description;
      _amountCtrl.text = e.amount.toString();
      _date = e.date;
      _type = e.type;
      _category = e.category;
    } else {
      _date = DateTime.now();
      _type = 0;
      _category = 0;
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      String? screenshotPath;

      if (widget.pendingCapture != null) {
        try {
          screenshotPath = await ScreenshotService.saveScreenshotToPublicFolder(
            File(widget.pendingCapture.path),
          );
        } catch (e) {
          setState(() => _saving = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to save screenshot: $e')),
            );
          }
          return;
        }
      }

      final body = <String, dynamic>{
        'date': DateFormat('yyyy-MM-dd').format(_date),
        'description': _descCtrl.text.trim(),
        'category': _category,
        'type': _type,
        'amount': double.parse(_amountCtrl.text.trim()),
      };
      if (_isEditing && widget.entry!.screenshotPath != null) {
        body['screenshotPath'] = widget.entry!.screenshotPath;
      } else if (screenshotPath != null) {
        body['screenshotPath'] = screenshotPath;
      }

      if (_isEditing) {
        await widget.api.updateEntry(widget.entry!.id, body);
        if (mounted) {
          showSuccessSnackBar(context, 'Updated successfully');
          Navigator.pop(context, true);
        }
      } else {
        await widget.api.createEntry(body);
        if (mounted) {
          if (widget.pendingCapture != null) {
            PendingStore().remove(widget.pendingCapture.path);
            showSuccessSnackBar(context, 'Added new entry');
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/dashboard',
              (route) => false,
            );
          } else {
            Navigator.pop(context, true);
          }
        }
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _filteredCategories;
    if (!categories.contains(_category)) {
      _category = categories.first;
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Entry' : 'New Entry')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Expense')),
                ButtonSegment(value: 1, label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() {
                _type = v.first;
                _category = _filteredCategories.first;
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
                prefixText: 'Rs. ',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (double.tryParse(v.trim()) == null ||
                    double.parse(v.trim()) <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categoryItems,
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(DateFormat('MMM dd, yyyy').format(_date)),
              trailing: const Icon(Icons.edit),
              enabled: !_isEditing,
              onTap: _isEditing
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
            ),
            if (widget.pendingCapture != null) ...[
              const SizedBox(height: 8),
              const Text('Attached Screenshot',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(widget.pendingCapture.path),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
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
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Captured ${widget.pendingCapture.capturedAt}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
            if (_isEditing && widget.entry!.screenshotPath != null) ...[
              const SizedBox(height: 8),
              const Text('Attached Screenshot',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(widget.entry!.screenshotPath!),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
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
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Update Entry' : 'Save Entry'),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isEditing => widget.entry != null;

  List<int> get _filteredCategories {
    if (_type == 0) {
      return [0, 1, 2];
    }
    return [3];
  }

  List<DropdownMenuItem<int>> get _categoryItems {
    return _filteredCategories.map((c) {
      final label = {
        0: 'PersonalPayment',
        1: 'BillSharing',
        2: 'Loan',
        3: 'Income',
      }[c] ?? 'Unknown';
      return DropdownMenuItem(value: c, child: Text(label));
    }).toList();
  }
bool _saving = false;
}