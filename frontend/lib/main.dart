import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/settings_providers.dart';
import 'config/api_config.dart';
import 'services/api_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/entry_list_screen.dart';
import 'screens/pending_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';

final _api = ApiService(ApiConfig.baseUrl);
final RouteObserver<ModalRoute> routeObserver = RouteObserver<ModalRoute>();

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Finance Tracker',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      themeMode: themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      initialRoute: '/dashboard',
      routes: {
        '/dashboard': (context) => DashboardScreen(api: _api),
        '/pending': (context) => PendingScreen(api: _api),
        '/transactions': (context) => EntryListScreen(api: _api),
        '/reports': (context) => ReportsScreen(api: _api),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
