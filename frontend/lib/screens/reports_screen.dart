import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/entry.dart';
import '../models/pending_store.dart';
import '../models/trial_balance_item.dart';
import '../providers/drawer_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/date_display.dart';
import 'transaction_detail_screen.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  final ApiService api;
  const ReportsScreen({super.key, required this.api});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  TrialBalanceResponse? _trialBalance;
  List<Entry> _entries = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentDrawerDestinationProvider.notifier).state = DrawerDestination.reports;
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final from = DateTime(_year, _month, 1);
      final to = DateTime(_year, _month + 1, 0);
      final results = await Future.wait([
        widget.api.getTrialBalance(year: _year, month: _month),
        widget.api.getEntries(from: from, to: to),
      ]);
      setState(() {
        _trialBalance = results[0] as TrialBalanceResponse;
        _entries = results[1] as List<Entry>;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _catName(int c) =>
      const {0: 'PersonalPayment', 1: 'BillSharing', 2: 'Loan', 3: 'Income'}[c] ?? 'Unknown';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false),
              child: CircleAvatar(
                radius: 22,
                backgroundImage: AssetImage('assets/images/logoST.png'),
              ),
            ),
          ),
        ],
      ),
      drawer: AppDrawer(pendingCount: PendingStore().length),
      body: Column(
        children: [
          _buildMonthPicker(),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Trial Balance'),
              Tab(text: 'Transactions'),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTrialBalance(),
                      _buildTransactions(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Month: ', style: TextStyle(fontWeight: FontWeight.w500)),
          DropdownButton<int>(
            value: _month,
            items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(DateFormat('MMMM').format(DateTime(2000, i + 1))))),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _month = v);
              _loadData();
            },
          ),
          const SizedBox(width: 16),
          const Text('Year: ', style: TextStyle(fontWeight: FontWeight.w500)),
          DropdownButton<int>(
            value: _year,
            items: List.generate(5, (i) {
              final y = DateTime.now().year - 2 + i;
              return DropdownMenuItem(value: y, child: Text('$y'));
            }),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _year = v);
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrialBalance() {
    if (_trialBalance == null || _trialBalance!.items.isEmpty) {
      return const Center(child: Text('No data for this month'));
    }

    final fmt = NumberFormat.currency(symbol: 'Rs. ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trial Balance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'For the month of ${DateFormat('MMMM yyyy').format(DateTime(_year, _month))}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Table(
            border: TableBorder.all(color: Colors.grey.shade400),
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1.5),
              2: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: [
                  _headerCell('Account Name'),
                  _headerCell('Debit'),
                  _headerCell('Credit'),
                ],
              ),
              ..._trialBalance!.items.map((item) => TableRow(
                    children: [
                      _dataCell(item.category),
                      _dataCell(item.debitTotal > 0 ? fmt.format(item.debitTotal) : ''),
                      _dataCell(item.creditTotal > 0 ? fmt.format(item.creditTotal) : ''),
                    ],
                  )),
              TableRow(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.black, width: 2)),
                ),
                children: [
                  _dataCell('Totals', isBold: true),
                  _dataCell(fmt.format(_trialBalance!.totalDebit), isBold: true),
                  _dataCell(fmt.format(_trialBalance!.totalCredit), isBold: true),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _dataCell(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _buildTransactions() {
    if (_entries.isEmpty) {
      return const Center(child: Text('No transactions this month'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _entries.length,
        itemBuilder: (_, i) => _buildEntryTile(_entries[i]),
      ),
    );
  }

  Widget _buildEntryTile(Entry entry) {
    final isIncome = entry.type == 1;
    return GestureDetector(
      onDoubleTap: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionDetailScreen(entry: entry, api: widget.api),
          ),
        );
        if (result == true) _loadData();
      },
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
            child: Icon(
              isIncome ? Icons.arrow_upward : Icons.arrow_downward,
              color: isIncome ? Colors.green : Colors.red,
            ),
          ),
          title: Text(entry.description),
          subtitle: Row(
            children: [
              DateDisplay(entry: entry),
              Text('  •  ${_catName(entry.category)}'),
            ],
          ),
          trailing: Text(
            '${isIncome ? '+' : '-'}${NumberFormat.currency(symbol: 'Rs. ').format(entry.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isIncome ? Colors.green : Colors.red,
            ),
          ),
        ),
      ),
    );
  }
}
