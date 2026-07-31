import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import '../models/entry.dart';
import '../models/pending_store.dart';
import '../models/trial_balance_item.dart';
import '../providers/drawer_provider.dart';
import '../providers/settings_providers.dart';
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
  late int _adYear;
  late int _adMonth;
  late int _bsYear;
  late int _bsMonth;
  TrialBalanceResponse? _trialBalance;
  List<Entry> _entries = [];
  bool _loading = false;

  bool get _isBs => ref.read(dateFormatProvider) == DateFormatMode.bs;

  int get _bsYearMin => NepaliDateTime.now().year - 3;
  int get _bsYearMax => NepaliDateTime.now().year + 5;

  List<int> get _adYears {
    final adMin = NepaliDateTime(_bsYearMin, 1, 1).toDateTime().year;
    final adMax = NepaliDateTime(_bsYearMax, 12, 30).toDateTime().year;
    return List.generate(adMax - adMin + 1, (i) => adMin + i);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _adYear = now.year;
    _adMonth = now.month;
    final nowBs = now.toNepaliDateTime();
    _bsYear = nowBs.year;
    _bsMonth = nowBs.month;
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
      final bs = _isBs;
      Future<TrialBalanceResponse> tbFuture;
      Future<List<Entry>> entriesFuture;
      if (bs) {
        tbFuture = widget.api.getTrialBalance(bsYear: _bsYear, bsMonth: _bsMonth);
        entriesFuture = widget.api.getEntries(bsYear: _bsYear, bsMonth: _bsMonth);
      } else {
        final from = DateTime(_adYear, _adMonth, 1);
        final to = DateTime(_adYear, _adMonth + 1, 0);
        tbFuture = widget.api.getTrialBalance(year: _adYear, month: _adMonth);
        entriesFuture = widget.api.getEntries(from: from, to: to);
      }
      final results = await Future.wait([tbFuture, entriesFuture]);
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

  void _syncBsFromAd() {
    final bs = DateTime(_adYear, _adMonth, 15).toNepaliDateTime();
    _bsYear = bs.year;
    _bsMonth = bs.month;
  }

  void _syncAdFromBs() {
    final ad = NepaliDateTime(_bsYear, _bsMonth, 15).toDateTime();
    _adYear = ad.year;
    _adMonth = ad.month;
  }

  String _catName(int c) =>
      const {0: 'PersonalPayment', 1: 'BillSharing', 2: 'Loan', 3: 'Income'}[c] ?? 'Unknown';

  Color _incomeColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? Colors.green.shade400 : Colors.green;

  Color _expenseColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? Colors.red.shade400 : Colors.red;

  @override
  Widget build(BuildContext context) {
    ref.watch(dateFormatProvider);
    ref.listen<DateFormatMode>(dateFormatProvider, (prev, next) {
      if (prev != next) _loadData();
    });
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
      child: _isBs ? _buildBsPeriodField() : _buildAdPeriodPicker(),
    );
  }

  Widget _buildAdPeriodPicker() {
    return Row(
      children: [
        const Text('AD Month: ', style: TextStyle(fontWeight: FontWeight.w500)),
        DropdownButton<int>(
          value: _adMonth,
          items: List.generate(12, (i) => DropdownMenuItem(
            value: i + 1,
            child: Text(DateFormat('MMMM').format(DateTime(2000, i + 1))),
          )),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _adMonth = v;
              _syncBsFromAd();
            });
            _loadData();
          },
        ),
        const SizedBox(width: 16),
        const Text('AD Year: ', style: TextStyle(fontWeight: FontWeight.w500)),
        DropdownButton<int>(
          value: _adYear,
          items: _adYears
              .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _adYear = v;
              _syncBsFromAd();
            });
            _loadData();
          },
        ),
      ],
    );
  }

  Widget _buildBsPeriodField() {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _pickBsMonth,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month, size: 20, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'BS Month: ${NepaliDateTime(_bsYear, _bsMonth, 1).format('MMMM yyyy')}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBsMonth() async {
    final first = NepaliDateTime(_bsYearMin, 1, 1);
    final last = NepaliDateTime(_bsYearMax, 12, 30);
    final current = NepaliDateTime(_bsYear, _bsMonth, 1);
    final initial = current.isBefore(first)
        ? first
        : (current.isAfter(last) ? last : current);
    final picked = await showMaterialDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _bsYear = picked.year;
      _bsMonth = picked.month;
      _syncAdFromBs();
    });
    _loadData();
  }

  Widget _buildTrialBalance() {
    if (_trialBalance == null || _trialBalance!.items.isEmpty) {
      return Center(child: Text('No data for this month', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)));
    }

    final fmt = NumberFormat.currency(symbol: 'Rs. ');
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trial Balance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            _isBs
                ? 'For the month of ${NepaliDateTime(_bsYear, _bsMonth, 1).format('MMMM yyyy')}'
                : 'For the month of ${DateFormat('MMMM yyyy').format(DateTime(_adYear, _adMonth))}',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Table(
            border: TableBorder.all(color: isDark ? cs.outline.withValues(alpha: 0.6) : cs.outline),
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1.5),
              2: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: cs.surfaceContainerHighest),
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
                  border: Border(top: BorderSide(color: cs.onSurface, width: 2)),
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
      child: Text(text,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
    );
  }

  Widget _dataCell(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: Theme.of(context).colorScheme.onSurface,
        ),
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
            backgroundColor: isIncome
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.errorContainer,
            child: Icon(
              isIncome ? Icons.arrow_upward : Icons.arrow_downward,
              color: isIncome ? _incomeColor(context) : _expenseColor(context),
            ),
          ),
          title: Text(entry.description),
          subtitle: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: DateDisplay(entry: entry, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Flexible(
                      child: Text('  •  ${_catName(entry.category)}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ],
          ),
          trailing: Text(
            '${isIncome ? '+' : '-'}${NumberFormat.currency(symbol: 'Rs. ').format(entry.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isIncome ? _incomeColor(context) : _expenseColor(context),
            ),
          ),
        ),
      ),
    );
  }
}
