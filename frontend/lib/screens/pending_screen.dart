import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/pending_store.dart';
import '../providers/drawer_provider.dart';
import '../services/api_service.dart';
import '../services/screenshot_service.dart';
import '../widgets/app_drawer.dart';
import 'entry_form_screen.dart';

class PendingScreen extends ConsumerStatefulWidget {
  final ApiService api;

  const PendingScreen({super.key, required this.api});

  @override
  ConsumerState<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends ConsumerState<PendingScreen> {
  final _store = PendingStore();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentDrawerDestinationProvider.notifier).state = DrawerDestination.pending;
    });
  }

  Future<void> _pickAndAddCapture() async {
    final granted = await ScreenshotService.checkAndRequestPermission(context);
    if (!granted) return;
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final storedPath = await ScreenshotService.saveScreenshotToPublicFolder(File(picked.path));
    setState(() {
      _store.add(PendingCapture(
        path: storedPath,
        capturedAt: DateTime.now(),
      ));
    });
  }

  void _openForm(PendingCapture capture) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EntryFormScreen(api: widget.api, pendingCapture: capture),
      ),
    );
    if (result == true) {
      setState(() {
        _store.remove(capture.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending'),
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
      drawer: AppDrawer(pendingCount: _store.length),
      body: _store.items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pending_actions, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No pending captures',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('Captured screenshots will appear here',
                      style: TextStyle(color: Colors.grey.shade500)),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _pickAndAddCapture,
                    icon: const Icon(Icons.add),
                    label: const Text('Attach Screenshot'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _store.items.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text('${_store.length} pending',
                              style: Theme.of(context).textTheme.titleSmall),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _pickAndAddCapture,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Attach'),
                          ),
                        ],
                      ),
                    );
                  }
                  final capture = _store.items[index - 1];
                  return Card(
                    child: ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.screenshot, color: Colors.grey),
                      ),
                      title: Text(
                        'Screenshot ${_store.length - index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        'Captured ${_formatTime(capture.capturedAt)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openForm(capture),
                    ),
                  );
                },
              ),
            ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}