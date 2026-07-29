import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DateFormatMode { ad, bs }

class DateFormatNotifier extends StateNotifier<DateFormatMode> {
  DateFormatNotifier() : super(DateFormatMode.ad);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString('dateFormat') ?? 'ad';
    state = val == 'bs' ? DateFormatMode.bs : DateFormatMode.ad;
  }

  Future<void> setMode(DateFormatMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dateFormat', mode == DateFormatMode.bs ? 'bs' : 'ad');
  }
}

final dateFormatProvider = StateNotifierProvider<DateFormatNotifier, DateFormatMode>((ref) {
  final notifier = DateFormatNotifier();
  notifier.load();
  return notifier;
});

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final notifier = ThemeModeNotifier();
  notifier.load();
  return notifier;
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString('themeMode') ?? 'system';
    state = switch (val) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    final val = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    await prefs.setString('themeMode', val);
  }
}
