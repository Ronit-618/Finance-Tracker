import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/api_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/entry_list_screen.dart';
import 'screens/pending_screen.dart';

final _api = ApiService('http://192.168.15.106:5044');

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finance Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      initialRoute: '/dashboard',
      routes: {
        '/dashboard': (context) => DashboardScreen(api: _api),
        '/pending': (context) => PendingScreen(api: _api),
        '/transactions': (context) => EntryListScreen(api: _api),
      },
    );
  }
}
