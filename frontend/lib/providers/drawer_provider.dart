import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DrawerDestination { dashboard, pending, transactions, reports, settings }

final currentDrawerDestinationProvider = StateProvider<DrawerDestination>((ref) => DrawerDestination.dashboard);
