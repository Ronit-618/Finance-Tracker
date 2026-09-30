import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/entry.dart';
import '../models/ledger_item.dart';
import '../models/loan.dart';
import '../models/pending_store.dart';
import '../models/saving.dart';
import '../providers/drawer_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/date_display.dart';
import '../widgets/network_error_view.dart';
import 'loan_detail_screen.dart';
import 'saving_detail_screen.dart';
import 'transaction_detail_screen.dart';

/// The unified ledger: every record the app can create — expenses, income,
/// savings, loans and loan repayments — in one date-sorted feed.
class EntryListScreen extends ConsumerStatefulWidget {
  final ApiService api;
  const EntryListScreen({super.key, required this.api});
  @override
  ConsumerState<EntryListScreen> createState() => _EntryListScreenState();
}

class _EntryListScreenState extends ConsumerState<EntryListScreen> {
  List<LedgerItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentDrawerDestinationProvider.notifier).state =
          DrawerDestination.transactions;
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final items = await widget.api.getLedger();
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      final message = friendlyError(e);
      setState(() {
        _loading = false;
        _error = message;
      });
      if (mounted && _items.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  void _retry() {
    setState(() => _error = null);
    _loadData();
  }

  int _catInt(String c) => const {
        'PersonalPayment': 0,
        'BillSharing': 1,
        'Loan': 2,
        'Income': 3,
      }[c] ??
      0;

  Entry _toEntry(LedgerItem i) => Entry(
        id: i.id,
        sn: i.sn,
        date: i.date,
        description: i.description,
        category: _catInt(i.category),
        type: i.type,
        paymentType: i.paymentType,
        amount: i.amount.abs(),
        screenshotPath: i.screenshotPath,
        isCompleted: i.isCompleted,
        createdAt: i.createdAt,
        bsDate: i.bsDate,
      );

  Saving _toSaving(LedgerItem i) => Saving(
        id: i.id,
        sn: i.sn,
        date: i.date,
        description: i.description,
        amount: i.amount.abs(),
        category: i.category,
        screenshotPath: i.screenshotPath,
        isCompleted: i.isCompleted,
        createdAt: i.createdAt,
        bsDate: i.bsDate,
      );

  Loan _toLoan(LedgerItem i) => Loan(
        id: i.id,
        sn: i.sn,
        date: i.date,
        description: i.description,
        amount: i.amount.abs(),
        fromPerson: i.fromPerson,
        toPerson: i.toPerson,
        direction: i.direction ?? 'Borrowed',
        category: i.category,
        isSettled: i.isSettled,
        screenshotPath: i.screenshotPath,
        isCompleted: i.isCompleted,
        createdAt: i.createdAt,
        bsDate: i.bsDate,
        amountRepaid: i.amountRepaid,
      );

  Future<void> _openDetail(LedgerItem item) async {
    final navigator = Navigator.of(context);
    Widget? target;
    switch (item.kind) {
      case 'saving':
        target = SavingDetailScreen(saving: _toSaving(item), api: widget.api);
        break;
      case 'loan':
        target = LoanDetailScreen(loan: _toLoan(item), api: widget.api);
        break;
      case 'repayment':
        if (item.loanId != null) {
          try {
            final loan = await widget.api.getLoan(item.loanId!);
            if (mounted) {
              target = LoanDetailScreen(loan: loan, api: widget.api);
            }
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not open the parent loan')),
              );
            }
            return;
          }
        }
        break;
      default:
        target =
            TransactionDetailScreen(entry: _toEntry(item), api: widget.api);
    }
    if (target == null) return;
    final result = await navigator.push<bool>(
      MaterialPageRoute(builder: (_) => target!),
    );
    if (result == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
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
          : _error != null && _items.isEmpty
              ? NetworkErrorView(message: _error!, onRetry: _retry)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: _items.isEmpty
                      ? ListView(
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: Text('No records yet')),
                            ),
                          ],
                        )
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (_, i) => _buildTile(_items[i]),
                        ),
                ),
    );
  }

  Widget _buildTile(LedgerItem item) {
    final style = _kindStyle(item);
    final amount = NumberFormat.currency(symbol: 'Rs. ')
        .format(item.amount.abs());
    final sign = item.isMoneyIn ? '+' : '-';

    return GestureDetector(
      onDoubleTap: () => _openDetail(item),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: style.color.withValues(alpha: 0.15),
            child: Icon(style.icon, color: style.color),
          ),
          title: Text(item.description),
          subtitle: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: DateDisplay(
                        date: item.date,
                        bsDate: item.bsDate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '  •  ${_subtitleLabel(item)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          trailing: Text(
            '$sign$amount',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: style.color,
            ),
          ),
        ),
      ),
    );
  }

  String _subtitleLabel(LedgerItem item) {
    if (item.kind == 'loan') {
      final person = item.person;
      return person == null ? 'Loan' : 'Loan • $person';
    }
    if (item.kind == 'repayment') return 'Repayment';
    return item.subCategory ?? item.category;
  }

  ({IconData icon, Color color}) _kindStyle(LedgerItem item) {
    switch (item.kind) {
      case 'income':
        return (icon: Icons.arrow_upward, color: Colors.green);
      case 'saving':
        return (icon: Icons.savings, color: Colors.blue);
      case 'loan':
        return (icon: Icons.handshake, color: Colors.purple);
      case 'repayment':
        return (icon: Icons.replay, color: Colors.orange);
      default:
        return (icon: Icons.arrow_downward, color: Colors.red);
    }
  }
}
