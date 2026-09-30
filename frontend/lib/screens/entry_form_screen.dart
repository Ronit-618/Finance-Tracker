import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import '../models/entry.dart';
import '../models/loan.dart';
import '../models/saving.dart';
import '../providers/settings_providers.dart';
import '../services/api_service.dart';
import '../services/screenshot_service.dart';
import '../models/pending_store.dart';
import '../utils/snackbar_helper.dart';

/// Which of the four v2 forms is showing. [expense] and [income] post to
/// /api/Entry; [saving] and [loan] post to their own endpoints.
enum EntryFormTab { expense, income, saving, loan }

class EntryFormScreen extends ConsumerStatefulWidget {
  final ApiService api;
  final Entry? entry;
  final Saving? saving;
  final Loan? loan;
  final dynamic pendingCapture;

  const EntryFormScreen({
    super.key,
    required this.api,
    this.entry,
    this.saving,
    this.loan,
    this.pendingCapture,
  });

  @override
  ConsumerState<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends ConsumerState<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();

  late DateTime _date;
  late int _type;
  late int _category;
  late String _subCategory;
  late EntryFormTab _tab;
  bool _saving = false;

  bool get _isEditing =>
      widget.entry != null || widget.saving != null || widget.loan != null;

  bool get _isLoan => _tab == EntryFormTab.loan;

  bool get _isSaving => _tab == EntryFormTab.saving;

  /// The existing screenshot on disk, whichever record is being edited.
  String? get _existingScreenshotPath =>
      widget.entry?.screenshotPath ??
      widget.saving?.screenshotPath ??
      widget.loan?.screenshotPath;

  @override
  void initState() {
    super.initState();

    final e = widget.entry;
    final s = widget.saving;
    final l = widget.loan;

    if (e != null) {
      _descCtrl.text = e.description;
      _amountCtrl.text = e.amount.toString();
      _date = e.date;
      _type = e.type;
      _category = e.category;
      _subCategory = e.subCategory ?? _subCategories.first;
      _tab = e.type == 1 ? EntryFormTab.income : EntryFormTab.expense;
    } else if (s != null) {
      _descCtrl.text = s.description;
      _amountCtrl.text = s.amount.toString();
      _date = s.date;
      _tab = EntryFormTab.saving;
      _category = _savingCategory;
    } else if (l != null) {
      _descCtrl.text = l.description;
      _amountCtrl.text = l.amount.toString();
      _date = l.date;
      _fromCtrl.text = l.fromPerson ?? '';
      _toCtrl.text = l.toPerson ?? '';
      _tab = EntryFormTab.loan;
      _category = _loanCategory;
    } else {
      _date = DateTime.now();
      _tab = EntryFormTab.expense;
      _type = 0;
      _category = 0;
      _subCategory = _subCategories.first;
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  void _selectTab(EntryFormTab tab) {
    setState(() {
      _tab = tab;
      // Category is always derived from the tab, never trusted from the user.
      if (tab == EntryFormTab.saving) {
        _category = _savingCategory;
      } else if (tab == EntryFormTab.loan) {
        _category = _loanCategory;
      } else {
        _type = tab == EntryFormTab.income ? 1 : 0;
        _category = _filteredCategories.first;
        _subCategory = _subCategories.first;
      }
    });
  }

  /// Loan: exactly one of From/To. Typing in one clears the other, so the
  /// controllers stay in sync with the enabled state.
  void _onFromChanged(String value) {
    if (value.trim().isNotEmpty && _toCtrl.text.isNotEmpty) {
      _toCtrl.clear();
    }
    setState(() {});
  }

  void _onToChanged(String value) {
    if (value.trim().isNotEmpty && _fromCtrl.text.isNotEmpty) {
      _fromCtrl.clear();
    }
    setState(() {});
  }

  String? _validateParty(String? value) {
    if (_fromCtrl.text.trim().isEmpty && _toCtrl.text.trim().isEmpty) {
      return 'Enter who you borrowed from, or who you lent to';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isLoan &&
        _fromCtrl.text.trim().isEmpty &&
        _toCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter who you borrowed from, or who you lent to'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      String? screenshotPath;

      if (widget.pendingCapture != null) {
        try {
          screenshotPath = await ScreenshotService.saveScreenshotToPublicFolder(
            File(widget.pendingCapture.path),
            subfolder: _isSaving
                ? 'Saving'
                : _isLoan
                    ? 'Loan'
                    : 'Transaction',
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

      final desc = _descCtrl.text.trim();
      final amount = double.parse(_amountCtrl.text.trim());

      // On edit, re-send the stored path so a server that only overwrites when
      // a value is present keeps the screenshot (bug #23 lesson).
      final screenshot =
          (_isEditing && _existingScreenshotPath != null)
              ? _existingScreenshotPath
              : screenshotPath;

      if (_isSaving) {
        final body = <String, dynamic>{
          if (!_isEditing) 'date': DateFormat('yyyy-MM-dd').format(_date),
          'description': desc,
          'amount': amount,
          'screenshotPath': ?screenshot,
        };
        if (_isEditing) {
          await widget.api.updateSaving(widget.saving!.id, body);
        } else {
          await widget.api.createSaving(body);
        }
      } else if (_isLoan) {
        final body = <String, dynamic>{
          if (!_isEditing) 'date': DateFormat('yyyy-MM-dd').format(_date),
          'description': desc,
          'amount': amount,
          'fromPerson': _fromCtrl.text.trim().isEmpty
              ? null
              : _fromCtrl.text.trim(),
          'toPerson':
              _toCtrl.text.trim().isEmpty ? null : _toCtrl.text.trim(),
          'screenshotPath': ?screenshot,
        };
        if (_isEditing) {
          await widget.api.updateLoan(widget.loan!.id, body);
        } else {
          await widget.api.createLoan(body);
        }
      } else {
        final body = <String, dynamic>{
          if (!_isEditing) 'date': DateFormat('yyyy-MM-dd').format(_date),
          'description': desc,
          'category': _category,
          if (_category == _personalPayment) 'subCategory': _subCategory,
          'type': _type,
          'amount': amount,
          'screenshotPath': ?screenshot,
        };
        if (_isEditing) {
          await widget.api.updateEntry(widget.entry!.id, body);
        } else {
          await widget.api.createEntry(body);
        }
      }

      if (!mounted) return;

      if (_isEditing) {
        showSuccessSnackBar(context, 'Updated successfully');
        Navigator.pop(context, true);
      } else if (widget.pendingCapture != null) {
        PendingStore().remove(widget.pendingCapture.path);
        showSuccessSnackBar(context, 'Added new entry');
        Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _filteredCategories;
    if (categories.isNotEmpty && !categories.contains(_category)) {
      _category = categories.first;
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Entry' : 'New Entry')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTabBar(),
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
            if (_isLoan) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _fromCtrl,
                onChanged: _onFromChanged,
                enabled: _toCtrl.text.trim().isEmpty,
                decoration: const InputDecoration(
                  labelText: 'From',
                  helperText: "From = you'll pay it back later",
                  helperMaxLines: 2,
                  border: OutlineInputBorder(),
                ),
                validator: _validateParty,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _toCtrl,
                onChanged: _onToChanged,
                enabled: _fromCtrl.text.trim().isEmpty,
                decoration: const InputDecoration(
                  labelText: 'To',
                  helperText: "To = you'll get it back later",
                  helperMaxLines: 2,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_isSaving)
              _lockedCategoryField('Saving')
            else if (_isLoan)
              _lockedCategoryField('Loan')
            else
              DropdownButtonFormField<int>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categoryItems(categories),
                onChanged: (v) => setState(() => _category = v!),
              ),
            if (_category == _personalPayment) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _subCategory,
                decoration: const InputDecoration(
                  labelText: 'Sub-category',
                  border: OutlineInputBorder(),
                ),
                items: _subCategories
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _subCategory = v!),
              ),
            ],
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(
                ref.watch(dateFormatProvider) == DateFormatMode.bs
                    ? _date.toNepaliDateTime().format('MMM dd, yyyy')
                    : DateFormat('MMM dd, yyyy').format(_date),
              ),
              trailing: const Icon(Icons.edit),
              enabled: !_isEditing,
              onTap: _isEditing
                  ? null
                  : () async {
                      if (ref.read(dateFormatProvider) == DateFormatMode.bs) {
                        final picked = await showMaterialDatePicker(
                          context: context,
                          firstDate: NepaliDateTime(2055, 1, 1),
                          lastDate: NepaliDateTime(2090, 12, 30),
                          initialDate: _date.toNepaliDateTime(),
                        );
                        if (picked != null) {
                          setState(() => _date = picked.toDateTime());
                        }
                      } else {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _date = picked);
                      }
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
                  errorBuilder: (context, error, stackTrace) =>
                      _screenshotFallback(),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Captured ${widget.pendingCapture.capturedAt}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
            if (_isEditing && _existingScreenshotPath != null) ...[
              const SizedBox(height: 8),
              const Text('Attached Screenshot',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_existingScreenshotPath!),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      _screenshotFallback(),
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

  Widget _buildTabBar() {
    const tabs = <({EntryFormTab tab, String label, IconData icon})>[
      (tab: EntryFormTab.expense, label: 'Expense', icon: Icons.arrow_downward),
      (tab: EntryFormTab.income, label: 'Income', icon: Icons.arrow_upward),
      (tab: EntryFormTab.saving, label: 'Saving', icon: Icons.savings),
      (tab: EntryFormTab.loan, label: 'Loan', icon: Icons.handshake),
    ];

    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final t in tabs)
            Expanded(
              flex: _tab == t.tab ? 2 : 1,
              child: InkWell(
                onTap: () => _selectTab(t.tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _tab == t.tab ? scheme.primaryContainer : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        t.icon,
                        size: 18,
                        color: _tab == t.tab
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                      if (_tab == t.tab) ...[
                        const SizedBox(width: 6),
                        Text(
                          t.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _lockedCategoryField(String label) {
    return TextFormField(
      initialValue: label,
      readOnly: true,
      enabled: false,
      decoration: const InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(),
        helperText: 'Fixed for this type',
      ),
    );
  }

  Widget _screenshotFallback() {
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
          Text(
            'Screenshot unavailable',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  static const int _savingCategory = 4;
  static const int _loanCategory = 2;
  static const int _personalPayment = 0;
  static const _subCategories = ['Food', 'Fuel', 'Meat', 'Extra'];

  /// v1 keeps 0=PersonalPayment, 1=BillSharing, 2=Loan, 3=Income. The legacy
  /// `Loan` category is intentionally hidden from the Expense dropdown so new
  /// loans go through the Loan tab; old rows still display and keep their value.
  List<int> get _filteredCategories {
    if (_tab == EntryFormTab.income) return [3];
    return [0, 1];
  }

  List<DropdownMenuItem<int>> _categoryItems(List<int> categories) {
    final allowed = categories.toSet();
    // Preserve the category of a legacy expense row that used `Loan` (2).
    if (_isEditing && widget.entry != null && allowed.contains(widget.entry!.category)) {
      allowed.add(widget.entry!.category);
    }
    const labels = {
      0: 'PersonalPayment',
      1: 'BillSharing',
      2: 'Loan',
      3: 'Income',
    };
    return allowed
        .map((c) => DropdownMenuItem(value: c, child: Text(labels[c] ?? 'Unknown')))
        .toList()
      ..sort((a, b) => a.value!.compareTo(b.value!));
  }
}
