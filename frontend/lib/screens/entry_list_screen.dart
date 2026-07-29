import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/entry.dart';
import '../models/pending_store.dart';
import '../providers/drawer_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import 'transaction_detail_screen.dart';

class EntryListScreen extends ConsumerStatefulWidget {
  final ApiService api;
  const EntryListScreen({super.key, required this.api});
  @override
  ConsumerState<EntryListScreen> createState() => _EntryListScreenState();
}

class _EntryListScreenState extends ConsumerState<EntryListScreen> {
  List<Entry> _entries = [];
  bool _loading = true;

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
      final entries = await widget.api.getEntries();
      setState(() {
        _entries = entries;
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

  String _catName(int c) =>
      const {
        0: 'PersonalPayment',
        1: 'BillSharing',
        2: 'Loan',
        3: 'Income',
      }[c] ??
      'Unknown';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: CircleAvatar(
              radius: 22,
              backgroundImage: AssetImage('assets/images/logoST.png'),
            ),
          ),
        ],
      ),
      drawer: AppDrawer(pendingCount: PendingStore().length),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _entries.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No entries yet')),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _entries.length,
                      itemBuilder: (_, i) => _buildEntryTile(_entries[i]),
                    ),
            ),
    );
  }

  Widget _buildEntryTile(Entry entry) {
    final isIncome = entry.type == 1;
    return GestureDetector(
      onDoubleTap: () => _openDetail(entry),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isIncome
                ? Colors.green.shade100
                : Colors.red.shade100,
            child: Icon(
              isIncome ? Icons.arrow_upward : Icons.arrow_downward,
              color: isIncome ? Colors.green : Colors.red,
            ),
          ),
          title: Text(entry.description),
          subtitle: Text(
            '${DateFormat('MMM dd, yyyy').format(entry.date)}  •  ${_catName(entry.category)}',
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
