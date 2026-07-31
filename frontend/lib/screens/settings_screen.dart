import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pending_store.dart';
import '../providers/settings_providers.dart';
import '../widgets/app_drawer.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = ref.watch(dateFormatProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text('Date Format'),
              subtitle: Text(dateFormat == DateFormatMode.bs ? 'Bikram Sambat (BS)' : 'Gregorian (AD)'),
              value: dateFormat == DateFormatMode.bs,
              onChanged: (v) {
                ref.read(dateFormatProvider.notifier).setMode(
                  v ? DateFormatMode.bs : DateFormatMode.ad,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: const Text('Theme'),
              subtitle: Text(switch (themeMode) {
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
                _ => 'System default',
              }),
              value: themeMode == ThemeMode.dark,
              onChanged: (v) {
                ref.read(themeModeProvider.notifier).setMode(
                  v ? ThemeMode.dark : ThemeMode.light,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
