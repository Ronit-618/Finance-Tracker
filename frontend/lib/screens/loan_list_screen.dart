import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/loan.dart';
import '../models/pending_store.dart';
import '../providers/drawer_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/date_display.dart';
import '../widgets/network_error_view.dart';
import 'loan_detail_screen.dart';

class LoanListScreen extends ConsumerStatefulWidget {
  final ApiService api;

  const LoanListScreen({super.key, required this.api});

  @override
  ConsumerState<LoanListScreen> createState() => _LoanListScreenState();
}

class _LoanListScreenState extends ConsumerState<LoanListScreen> {
  List<Loan> _loans = [];
  LoanSummary? _summary;
  bool _loading = true;
  String? _error;

  /// null = All, 'borrowed', 'lent'
  String? _direction;
  /// null = All, true = Open, false = Settled
  bool? _isSettled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentDrawerDestinationProvider.notifier).state =
          DrawerDestination.loans;
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api.getLoans(direction: _direction, isSettled: _isSettled),
        widget.api.getLoanSummary(),
      ]);
      if (!mounted) return;
      setState(() {
        _loans = results[0] as List<Loan>;
        _summary = results[1] as LoanSummary;
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
      if (_loans.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  void _retry() {
    setState(() => _error = null);
    _loadData();
  }

  Future<void> _openDetail(Loan loan) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LoanDetailScreen(loan: loan, api: widget.api),
      ),
    );
    if (result == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loans'),
        actions: [
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _loans.isEmpty
              ? NetworkErrorView(message: _error!, onRetry: _retry)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (_summary != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _summaryCard(
                                'I Owe',
                                _summary!.payableOutstanding,
                                Colors.red,
                                Icons.arrow_upward,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _summaryCard(
                                'Owed To Me',
                                _summary!.receivableOutstanding,
                                Colors.green,
                                Icons.arrow_downward,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _chip('All', _direction == null, () {
                              setState(() => _direction = null);
                              _loadData();
                            }),
                            const SizedBox(width: 8),
                            _chip('Borrowed (I owe)', _direction == 'borrowed', () {
                              setState(() => _direction = 'borrowed');
                              _loadData();
                            }),
                            const SizedBox(width: 8),
                            _chip('Lent (owed to me)', _direction == 'lent', () {
                              setState(() => _direction = 'lent');
                              _loadData();
                            }),
                            const SizedBox(width: 16),
                            _chip('Open', _isSettled == false, () {
                              setState(() => _isSettled = false);
                              _loadData();
                            }),
                            const SizedBox(width: 8),
                            _chip('Settled', _isSettled == true, () {
                              setState(() => _isSettled = true);
                              _loadData();
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_loans.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No loans recorded yet')),
                        )
                      else
                        ..._loans.map(
                          (l) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onDoubleTap: () => _openDetail(l),
                              child: Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: l.isBorrowed
                                        ? Theme.of(context)
                                            .colorScheme
                                            .errorContainer
                                        : Theme.of(context)
                                            .colorScheme
                                            .primaryContainer,
                                    child: Icon(
                                      l.isBorrowed
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward,
                                      color: l.isBorrowed
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                  ),
                                  title: Text(
                                    l.description,
                                    style: TextStyle(
                                      decoration: l.isSettled
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: DateDisplay(
                                                date: l.date,
                                                bsDate: l.bsDate,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Flexible(
                                              child: Text(
                                                '  •  ${l.person ?? "—"}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        NumberFormat.currency(symbol: 'Rs. ')
                                            .format(l.amount),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: l.isBorrowed
                                              ? Colors.red
                                              : Colors.green,
                                        ),
                                      ),
                                      if (l.amountRepaid > 0)
                                        Text(
                                          '${NumberFormat.currency(symbol: 'Rs. ').format(l.outstanding)} left',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      if (l.isSettled)
                                        Text(
                                          'Settled',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                    ],
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

  Widget _summaryCard(String label, double amount, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              child: Text(
                NumberFormat.currency(symbol: 'Rs. ').format(amount),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
