import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/entry.dart';
import '../models/entry_summary.dart';
import '../services/api_service.dart';
import 'transaction_detail_screen.dart';

class TableScreen extends StatefulWidget {
  final ApiService api;
  const TableScreen({super.key, required this.api});

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  List<Entry> _entries = [];
  EntrySummary? _summary;
  bool _loading = true;

  DateTime? _filterFrom;
  DateTime? _filterTo;
  int? _filterCategory;
  int? _filterType;
  String _groupBy = 'none';

  String _catName(int c) => const {0:'PersonalPayment',1:'BillSharing',2:'Loan',3:'Income'}[c] ?? 'Unknown';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api.getEntries(
          from: _filterFrom,
          to: _filterTo,
          category: _filterCategory,
          type: _filterType,
        ),
        widget.api.getSummary(
          from: _filterFrom,
          to: _filterTo,
          category: _filterCategory,
          type: _filterType,
        ),
      ]);
      setState(() {
        _entries = results[0] as List<Entry>;
        _summary = results[1] as EntrySummary;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _openDetail(Entry entry) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(entry: entry, api: widget.api),
      ),
    );
    if (result == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildSummaryBar(),
          const SizedBox(height: 8),
          _buildFilters(),
          const SizedBox(height: 8),
          _buildGroupByToggle(),
          const Divider(),
          if (_entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No entries match filters')),
            )
          else
            ..._buildGroupedEntries(),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    if (_summary == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _summaryLabel('Entries', '${_summary!.totalEntries}', Colors.grey),
            _summaryLabel(
              'Income',
              NumberFormat.currency(
                symbol: 'Rs. ',
              ).format(_summary!.totalIncome),
              Colors.green,
            ),
            _summaryLabel(
              'Expense',
              NumberFormat.currency(
                symbol: 'Rs. ',
              ).format(_summary!.totalExpense),
              Colors.red,
            ),
            _summaryLabel(
              'Balance',
              NumberFormat.currency(symbol: 'Rs. ').format(_summary!.balance),
              _summary!.balance >= 0 ? Colors.blue : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryLabel(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _filterChip('All', null, _filterType, (v) => _filterType = v),
                const SizedBox(width: 4),
                _filterChip(
                  'Income',
                  1,
                  _filterType,
                  (v) => _filterType = v,
                ),
                const SizedBox(width: 4),
                _filterChip(
                  'Expense',
                  0,
                  _filterType,
                  (v) => _filterType = v,
                ),
                const Spacer(),
                if (_filterType != null || _filterCategory != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      setState(() {
                        _filterType = null;
                        _filterCategory = null;
                        _filterFrom = null;
                        _filterTo = null;
                      });
                      _loadData();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<int?>(
              initialValue: _filterCategory,
              decoration: const InputDecoration(
                labelText: 'Category filter',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All Categories'),
                ),
                ...[0,1,2,3].map(
                  (c) => DropdownMenuItem(value: c, child: Text(_catName(c))),
                ),
              ],
              onChanged: (v) {
                setState(() => _filterCategory = v);
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(
    String label,
    int? value,
    int? current,
    void Function(int?) onSelected,
  ) {
    final isSelected = current == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (s) {
        onSelected(s ? value : null);
        _loadData();
      },
    );
  }

  Widget _buildGroupByToggle() {
    return Row(
      children: [
        const Text('Group by: ', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'none',
              label: Text('None', style: TextStyle(fontSize: 11)),
            ),
            ButtonSegment(
              value: 'day',
              label: Text('Day', style: TextStyle(fontSize: 11)),
            ),
            ButtonSegment(
              value: 'month',
              label: Text('Month', style: TextStyle(fontSize: 11)),
            ),
            ButtonSegment(
              value: 'year',
              label: Text('Year', style: TextStyle(fontSize: 11)),
            ),
          ],
          selected: {_groupBy},
          onSelectionChanged: (v) => setState(() => _groupBy = v.first),
        ),
      ],
    );
  }

  List<Widget> _buildGroupedEntries() {
    if (_groupBy == 'none') {
      return _entries.map((e) => _EntryTile(
        entry: e,
        catName: _catName,
        onDoubleTap: () => _openDetail(e),
      )).toList();
    }

    String keyFn(Entry e) {
      switch (_groupBy) {
        case 'day':
          return DateFormat('yyyy-MM-dd').format(e.date);
        case 'month':
          return DateFormat('yyyy-MM').format(e.date);
        case 'year':
          return DateFormat('yyyy').format(e.date);
        default:
          return '';
      }
    }

    final grouped = <String, List<Entry>>{};
    for (final e in _entries) {
      grouped.putIfAbsent(keyFn(e), () => []).add(e);
    }

    final sortedKeys = grouped.keys.toList()..sort();
    final widgets = <Widget>[];
    for (final key in sortedKeys) {
      final group = grouped[key]!;
      final income = group
          .where((e) => e.type == 1)
          .fold<double>(0, (s, e) => s + e.amount);
      final expense = group
          .where((e) => e.type == 0)
          .fold<double>(0, (s, e) => s + e.amount);
      widgets.add(
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: ListTile(
            dense: true,
            title: Text(
              key,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${group.length} entries'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${NumberFormat.currency(symbol: 'Rs. ').format(income)}',
                  style: const TextStyle(color: Colors.green, fontSize: 11),
                ),
                Text(
                  '-${NumberFormat.currency(symbol: 'Rs. ').format(expense)}',
                  style: const TextStyle(color: Colors.red, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
      for (final entry in group) {
        widgets.add(_EntryTile(
          entry: entry,
          catName: _catName,
          onDoubleTap: () => _openDetail(entry),
        ));
      }
    }
    return widgets;
  }
}

class _EntryTile extends StatelessWidget {
  final Entry entry;
  final String Function(int) catName;
  final VoidCallback onDoubleTap;

  const _EntryTile({
    required this.entry,
    required this.catName,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final isIncome = e.type == 1;

    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isIncome
                ? Colors.green.shade100
                : Colors.red.shade100,
            child: Icon(
              isIncome ? Icons.arrow_upward : Icons.arrow_downward,
              color: isIncome ? Colors.green : Colors.red,
              size: 18,
            ),
          ),
          title: Text(e.description, style: const TextStyle(fontSize: 14)),
          subtitle: Text(
            '${DateFormat('MMM dd').format(e.date)}  •  ${catName(e.category)}',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: Text(
            '${isIncome ? '+' : '-'}${NumberFormat.currency(symbol: 'Rs. ').format(e.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isIncome ? Colors.green : Colors.red,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}