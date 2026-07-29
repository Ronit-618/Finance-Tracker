import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/drawer_provider.dart';

class AppDrawer extends ConsumerWidget {
  final int pendingCount;

  const AppDrawer({super.key, required this.pendingCount});

  void _navigateTo(BuildContext context, WidgetRef ref, String targetRoute, DrawerDestination dest) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    if (currentRoute == targetRoute) {
      Navigator.pop(context);
      return;
    }

    if (currentRoute == '/dashboard') {
      Navigator.pushNamed(context, targetRoute);
    } else if (currentRoute == '/pending' || currentRoute == '/transactions' || currentRoute == '/reports') {
      Navigator.pushReplacementNamed(context, targetRoute);
    } else {
      Navigator.popUntil(context, ModalRoute.withName('/dashboard'));
      Navigator.pushNamed(context, targetRoute);
    }

    ref.read(currentDrawerDestinationProvider.notifier).state = dest;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentDest = ref.watch(currentDrawerDestinationProvider);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundImage: AssetImage('assets/images/logoST.png'),
                ),
                const SizedBox(height: 8),
                Text('Finance Tracker',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            selected: currentDest == DrawerDestination.dashboard,
            onTap: () => _navigateTo(context, ref, '/dashboard', DrawerDestination.dashboard),
          ),
          ListTile(
            leading: const Icon(Icons.pending_actions),
            title: const Text('Pending'),
            trailing: pendingCount > 0
                ? Badge(
                    label: Text('$pendingCount'),
                    child: const Icon(Icons.pending_actions),
                  )
                : null,
            selected: currentDest == DrawerDestination.pending,
            onTap: () => _navigateTo(context, ref, '/pending', DrawerDestination.pending),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart),
            title: const Text('Transactions'),
            selected: currentDest == DrawerDestination.transactions,
            onTap: () => _navigateTo(context, ref, '/transactions', DrawerDestination.transactions),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Reports'),
            selected: currentDest == DrawerDestination.reports,
            onTap: () => _navigateTo(context, ref, '/reports', DrawerDestination.reports),
          ),
        ],
      ),
    );
  }
}
