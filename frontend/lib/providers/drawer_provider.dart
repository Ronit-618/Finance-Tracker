import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DrawerDestination { dashboard, pending, transactions }

final currentDrawerDestinationProvider = StateProvider<DrawerDestination>((ref) => DrawerDestination.dashboard);
