import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import '../models/loan.dart';
import '../models/loan_repayment.dart';
import '../providers/settings_providers.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import 'entry_form_screen.dart';
import 'transaction_detail_screen.dart' show FullScreenImage;
import '../widgets/record_screenshot.dart';

class LoanDetailScreen extends ConsumerStatefulWidget {
  final Loan loan;
  final ApiService api;

  const LoanDetailScreen({
    super.key,
    required this.loan,
    required this.api,
  });

  @override
  ConsumerState<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends ConsumerState<LoanDetailScreen> {
  late Loan _loan = widget.loan;
  List<LoanRepayment> _repayments = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Reloads the loan (for fresh outstanding/settled state) and its repayments.
  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.api.getLoan(widget.loan.id),
        widget.api.getLoanRepayments(widget.loan.id),
      ]);
      if (!mounted) return;
      setState(() {
        _loan = results[0] as Loan;
        _repayments = results[1] as List<LoanRepayment>;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _edit() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EntryFormScreen(api: widget.api, loan: _loan)),
    );
    if (result == true) {
      await _load();
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Loan'),
        content: Text('Delete "${_loan.description}"? Repayments recorded against it '
            'will be removed too.'),
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
        await widget.api.deleteLoan(_loan.id);
        if (mounted) {
          showSuccessSnackBar(context, 'Deleted successfully',
              backgroundColor: Colors.red);
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(friendlyError(e))));
        }
      }
    }
  }

  /// Manual settle is only meaningful when no repayments were recorded; the
  /// API auto-settles a loan once repayments reach the full amount.
  Future<void> _toggleSettled() async {
    setState(() => _busy = true);
    try {
      await widget.api.toggleLoanSettled(_loan.id);
      await _load();
      if (mounted) {
        showSuccessSnackBar(
          context,
          _loan.isSettled ? 'Marked as open' : 'Marked as settled',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addRepayment() async {
    final result = await showModalBottomSheet<_RepaymentDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RepaymentSheet(maxAmount: _loan.outstanding),
    );
    if (result == null) return;

    setState(() => _busy = true);
    try {
      await widget.api.createLoanRepayment(_loan.id, {
        'amount': result.amount,
        'date': DateFormat('yyyy-MM-dd').format(result.date),
        'note': result.note,
      });
      await _load();
      if (mounted) showSuccessSnackBar(context, 'Repayment recorded');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteRepayment(LoanRepayment r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Repayment'),
        content: Text('Remove the ${NumberFormat.currency(symbol: 'Rs. ').format(r.amount)} '
            'repayment? This re-opens the loan if it was fully settled.'),
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
    if (confirm != true) return;

    try {
      await widget.api.deleteLoanRepayment(r.id);
      await _load();
      if (mounted) showSuccessSnackBar(context, 'Repayment removed');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loan = _loan;
    final accent = loan.isBorrowed ? Colors.red : Colors.green;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            onPressed: _edit,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete',
            onPressed: _delete,
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
                        backgroundColor: loan.isBorrowed
                            ? Theme.of(context).colorScheme.errorContainer
                            : Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          loan.isBorrowed
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
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
                                decoration: loan.isSettled
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              NumberFormat.currency(symbol: 'Rs. ')
                                  .format(loan.amount),
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
                  if (loan.amountRepaid > 0) ...[
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _miniStat('Repaid',
                            NumberFormat.currency(symbol: 'Rs. ')
                                .format(loan.amountRepaid),
                            Colors.green),
                        _miniStat('Outstanding',
                            NumberFormat.currency(symbol: 'Rs. ')
                                .format(loan.outstanding),
                            loan.outstanding > 0 ? Colors.orange : Colors.green),
                      ],
                    ),
                  ],
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
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const Divider(),
                  RecordDetailRow(
                    label: 'Direction',
                    value: loan.isBorrowed
                        ? 'Borrowed (I owe)'
                        : 'Lent (owed to me)',
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
                    value: formatRecordDate(
                        context, ref, loan.date, loan.bsDate),
                  ),
                  RecordDetailRow(label: 'Category', value: loan.category),
                  if (loan.settledDate != null)
                    RecordDetailRow(
                      label: 'Settled on',
                      value:
                          DateFormat('MMM dd, yyyy').format(loan.settledDate!),
                    ),
                  RecordDetailRow(
                    label: 'Created',
                    value: DateFormat('MMM dd, yyyy – HH:mm')
                        .format(loan.createdAt),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!loan.isSettled && loan.outstanding > 0)
            FilledButton.icon(
              icon: const Icon(Icons.payments),
              label: Text(
                  'Record Repayment (${NumberFormat.currency(symbol: 'Rs. ').format(loan.outstanding)} due)'),
              onPressed: _busy ? null : _addRepayment,
            )
          else if (loan.amountRepaid == 0)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: loan.isSettled ? Colors.orange : Colors.green,
              ),
              icon: Icon(loan.isSettled ? Icons.undo : Icons.check),
              label: Text(loan.isSettled ? 'Mark as Open' : 'Mark as Settled'),
              onPressed: _busy ? null : _toggleSettled,
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Fully repaid',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (_repayments.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Repayments (${_repayments.length})',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const Divider(),
                    ..._repayments.map(_buildRepaymentRow),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Screenshot',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const Divider(),
                  RecordScreenshot(
                    path: loan.screenshotPath,
                    onView: (p) => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => FullScreenImage(path: p)),
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

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15, color: color)),
      ],
    );
  }

  Widget _buildRepaymentRow(LoanRepayment r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline,
              size: 18, color: Colors.green.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  NumberFormat.currency(symbol: 'Rs. ').format(r.amount),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.green),
                ),
                Text(
                  r.note == null || r.note!.isEmpty
                      ? formatRecordDate(context, ref, r.date, r.bsDate)
                      : '${formatRecordDate(context, ref, r.date, r.bsDate)} • ${r.note}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: Colors.red,
            tooltip: 'Delete repayment',
            onPressed: () => _deleteRepayment(r),
          ),
        ],
      ),
    );
  }
}

class _RepaymentDraft {
  final double amount;
  final DateTime date;
  final String? note;

  _RepaymentDraft({required this.amount, required this.date, this.note});
}

class _RepaymentSheet extends ConsumerStatefulWidget {
  final double maxAmount;

  const _RepaymentSheet({required this.maxAmount});

  @override
  ConsumerState<_RepaymentSheet> createState() => _RepaymentSheetState();
}

class _RepaymentSheetState extends ConsumerState<_RepaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _RepaymentDraft(
        amount: double.parse(_amountCtrl.text.trim()),
        date: _date,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBs = ref.watch(dateFormatProvider) == DateFormatMode.bs;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Record Repayment',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Outstanding: ${NumberFormat.currency(symbol: 'Rs. ').format(widget.maxAmount)}',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
                prefixText: 'Rs. ',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final parsed = double.tryParse(v.trim());
                if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                if (parsed > widget.maxAmount) {
                  return 'Cannot exceed ${widget.maxAmount.toStringAsFixed(2)}';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(
                isBs
                    ? _date.toNepaliDateTime().format('MMM dd, yyyy')
                    : DateFormat('MMM dd, yyyy').format(_date),
              ),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                if (isBs) {
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Record Repayment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
