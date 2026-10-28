import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_tracker/models/entry.dart';
import 'package:finance_tracker/models/trial_balance_item.dart';
import 'package:finance_tracker/providers/settings_providers.dart';
import 'package:finance_tracker/screens/reports_screen.dart';
import 'package:finance_tracker/services/api_service.dart';

class _StubApi extends ApiService {
  _StubApi() : super('https://example.com');

  @override
  Future<TrialBalanceResponse> getTrialBalance({
    int? year,
    int? month,
    int? bsYear,
    int? bsMonth,
    DateTime? from,
    DateTime? to,
  }) async {
    return TrialBalanceResponse(
      totalDebit: 100,
      totalCredit: 0,
      items: [TrialBalanceItem(category: 'PersonalPayment', debitTotal: 100, creditTotal: 0)],
    );
  }

  @override
  Future<List<Entry>> getEntries({
    DateTime? from,
    DateTime? to,
    int? category,
    int? type,
    int? paymentType,
    int? bsYear,
    int? bsMonth,
  }) async {
    final now = DateTime.now();
    return [
      Entry(
        id: 1,
        sn: 1,
        date: now,
        description: 'Test entry',
        category: 0,
        type: 0,
        paymentType: 0,
        amount: 100,
        isCompleted: 0,
        createdAt: now,
        bsDate: '13 Shrawan 2083',
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Reports dates follow the AD/BS toggle', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final now = DateTime.now();
    final bsNow = now.toNepaliDateTime();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final adSubtitle = 'For the month of ${months[now.month - 1]} ${now.year}';
    final adTile = '${months[now.month - 1].substring(0, 3)} ${now.day.toString().padLeft(2, '0')}, ${now.year}';
    final bsLabel = bsNow.format('MMMM yyyy');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: ReportsScreen(api: _StubApi())),
      ),
    );
    await tester.pumpAndSettle();

    // AD mode on Tab 0 (Trial Balance)
    expect(find.text('AD Month: '), findsOneWidget);
    expect(find.text(adSubtitle), findsOneWidget);

    // Switch to Transactions tab (Tab 1)
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();
    expect(find.text(adTile), findsOneWidget);
    expect(find.text('13 Shrawan 2083'), findsNothing);

    // Switch back to Trial Balance tab (Tab 0)
    await tester.tap(find.text('Trial Balance'));
    await tester.pumpAndSettle();

    // Switch to BS
    container.read(dateFormatProvider.notifier).setMode(DateFormatMode.bs);
    await tester.pumpAndSettle();

    // BS mode on Tab 0 (Trial Balance)
    expect(find.text('BS Month: $bsLabel'), findsOneWidget);
    expect(find.text('For the month of $bsLabel'), findsOneWidget);

    // Switch to Transactions tab (Tab 1)
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();
    expect(find.text('13 Shrawan 2083'), findsOneWidget);
    expect(find.text(adTile), findsNothing);

    // Switch back to AD
    container.read(dateFormatProvider.notifier).setMode(DateFormatMode.ad);
    await tester.pumpAndSettle();

    expect(find.text(adTile), findsOneWidget);
  });
}
