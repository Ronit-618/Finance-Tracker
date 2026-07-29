import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../main.dart' show routeObserver;
import '../models/category_total.dart';
import '../models/entry_group.dart';
import '../models/entry_summary.dart';
import '../models/pending_store.dart';
import '../providers/drawer_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/savings_chart.dart';
import '../widgets/expense_category_chart.dart';
import '../widgets/income_vs_expense_chart.dart';
import '../widgets/top_spending_list.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final ApiService api;
  const DashboardScreen({super.key, required this.api});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with RouteAware {
  EntrySummary? _summary;
  List<EntryGroup> _monthlyGroups = [];
  List<CategoryTotal> _categoryExpenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentDrawerDestinationProvider.notifier).state = DrawerDestination.dashboard;
    });
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api.getSummary(),
        widget.api.getGrouped(period: 'month'),
        widget.api.getCategoryTotals(type: 0),
      ]);
      setState(() {
        _summary = results[0] as EntrySummary;
        _monthlyGroups = results[1] as List<EntryGroup>;
        _categoryExpenses = results[2] as List<CategoryTotal>;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 24),
                  Text('Monthly Trend', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ..._monthlyGroups.reversed.take(6).map(_buildTrendRow),
                  const SizedBox(height: 24),
                  ExpenseCategoryChart(data: _categoryExpenses),
                  const SizedBox(height: 16),
                  IncomeVsExpenseChart(groups: _monthlyGroups),
                  const SizedBox(height: 16),
                  SavingsChart(groups: _monthlyGroups),
                  const SizedBox(height: 16),
                  TopSpendingList(data: _categoryExpenses),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    if (_summary == null) return const SizedBox.shrink();
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryItem('Income', _summary!.totalIncome, Colors.green),
                _summaryItem('Expense', _summary!.totalExpense, Colors.red),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Balance: ', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  NumberFormat.currency(symbol: 'Rs. ').format(_summary!.balance),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _summary!.balance >= 0 ? Colors.blue : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          NumberFormat.currency(symbol: 'Rs. ').format(amount),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendRow(EntryGroup group) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(group.period, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: group.totalIncome + group.totalExpense > 0
                    ? group.totalIncome / (group.totalIncome + group.totalExpense)
                    : 0.5,
                backgroundColor: Colors.red.shade100,
                color: Colors.green,
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              NumberFormat.currency(symbol: 'Rs. ').format(group.balance),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: group.balance >= 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
