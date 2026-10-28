import 'entry_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/pending_store.dart';
import '../models/saving.dart';
import '../providers/drawer_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/date_display.dart';
import '../widgets/network_error_view.dart';
import 'saving_detail_screen.dart';

class SavingListScreen extends ConsumerStatefulWidget {
  final ApiService api;

  const SavingListScreen({super.key, required this.api});

  @override
  ConsumerState<SavingListScreen> createState() => _SavingListScreenState();
}

class _SavingListScreenState extends ConsumerState<SavingListScreen> {
  List<Saving> _savings = [];
  SavingSummary? _summary;
  bool _loading = true;
  String? _error;
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentDrawerDestinationProvider.notifier).state =
          DrawerDestination.savings;
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api.getSavings(from: _range?.start, to: _range?.end),
        widget.api.getSavingSummary(from: _range?.start, to: _range?.end),
      ]);
      if (!mounted) return;
      setState(() {
        _savings = results[0] as List<Saving>;
        _summary = results[1] as SavingSummary;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      final message = friendlyError(e);
      setState(() {
        _loading = false;
        _error = message;
      });
      if (_savings.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  void _retry() {
    setState(() => _error = null);
    _loadData();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() => _range = picked);
    _loadData();
  }

  Future<void> _openDetail(Saving saving) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SavingDetailScreen(saving: saving, api: widget.api),
      ),
    );
    if (result == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Filter by date',
            onPressed: _pickRange,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () => Navigator.pushNamedAndRemoveUntil(
                  context, '/dashboard', (route) => false),
              child: CircleAvatar(
                radius: 22,
                backgroundImage: AssetImage('assets/images/logoST.png'),
              ),
            ),
          ),
        ],
      ),
      drawer: AppDrawer(pendingCount: PendingStore().length),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => EntryFormScreen(api: widget.api),
            ),
          );
          if (res == true) _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Saving / Withdrawal'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _savings.isEmpty
              ? NetworkErrorView(message: _error!, onRetry: _retry)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (_summary != null) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Current Savings',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      NumberFormat.currency(symbol: 'Rs. ')
                                          .format(_summary!.totalSaved),
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          'Deposited: ${NumberFormat.currency(symbol: 'Rs. ').format(_summary!.totalDeposited)}',
                                          style: const TextStyle(fontSize: 12, color: Colors.green),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Withdrawn: ${NumberFormat.currency(symbol: 'Rs. ').format(_summary!.totalWithdrawn)}',
                                          style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Text(
                                  '${_summary!.count} ${_summary!.count == 1 ? "entry" : "entries"}',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (_range != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${DateFormat('MMM dd, yyyy').format(_range!.start)} — ${DateFormat('MMM dd, yyyy').format(_range!.end)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() => _range = null);
                                  _loadData();
                                },
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                        ),
                      if (_savings.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text('No savings recorded yet'),
                          ),
                        )
                      else
                        ..._savings.map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onDoubleTap: () => _openDetail(s),
                              child: Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: s.isWithdrawal
                                        ? Theme.of(context).colorScheme.errorContainer
                                        : Theme.of(context).colorScheme.primaryContainer,
                                    child: Icon(
                                      s.isWithdrawal ? Icons.outbox : Icons.savings,
                                      color: s.isWithdrawal ? Colors.orange.shade800 : Colors.green,
                                    ),
                                  ),
                                  title: Text(s.description),
                                  subtitle: Row(
                                    children: [
                                      Flexible(
                                        child: DateDisplay(
                                          date: s.date,
                                          bsDate: s.bsDate,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Text('  •  '),
                                      Text(
                                        s.type,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: s.isWithdrawal ? Colors.orange.shade800 : Colors.green,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Text(
                                    '${s.isWithdrawal ? '-' : '+'}${NumberFormat.currency(symbol: 'Rs. ').format(s.amount)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: s.isWithdrawal ? Colors.orange.shade800 : Colors.green,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
