import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/models/saving.dart';

void main() {
  group('Saving Model Tests', () {
    test('Saving parses Deposit type correctly', () {
      final json = {
        'id': 1,
        'sn': 1,
        'date': '2026-10-28T00:00:00Z',
        'description': 'Monthly savings deposit',
        'amount': 5000.0,
        'category': 'Saving',
        'type': 'Deposit',
        'isCompleted': 0,
        'createdAt': '2026-10-28T00:00:00Z',
      };

      final saving = Saving.fromJson(json);

      expect(saving.id, 1);
      expect(saving.amount, 5000.0);
      expect(saving.type, 'Deposit');
      expect(saving.isDeposit, isTrue);
      expect(saving.isWithdrawal, isFalse);
    });

    test('Saving parses Withdrawal type correctly', () {
      final json = {
        'id': 2,
        'sn': 2,
        'date': '2026-10-28T00:00:00Z',
        'description': 'Emergency withdrawal',
        'amount': 2000.0,
        'category': 'Saving',
        'type': 'Withdrawal',
        'isCompleted': 0,
        'createdAt': '2026-10-28T00:00:00Z',
      };

      final saving = Saving.fromJson(json);

      expect(saving.id, 2);
      expect(saving.amount, 2000.0);
      expect(saving.type, 'Withdrawal');
      expect(saving.isWithdrawal, isTrue);
      expect(saving.isDeposit, isFalse);
    });

    test('Saving defaults to Deposit if type is omitted', () {
      final json = {
        'id': 3,
        'sn': 3,
        'date': '2026-10-28T00:00:00Z',
        'description': 'Legacy saving',
        'amount': 1500.0,
        'category': 'Saving',
        'isCompleted': 0,
        'createdAt': '2026-10-28T00:00:00Z',
      };

      final saving = Saving.fromJson(json);

      expect(saving.type, 'Deposit');
      expect(saving.isDeposit, isTrue);
      expect(saving.isWithdrawal, isFalse);
    });

    test('SavingSummary parses net saved, deposited, and withdrawn correctly', () {
      final json = {
        'totalSaved': 3000.0,
        'totalDeposited': 5000.0,
        'totalWithdrawn': 2000.0,
        'count': 2,
      };

      final summary = SavingSummary.fromJson(json);

      expect(summary.totalSaved, 3000.0);
      expect(summary.totalDeposited, 5000.0);
      expect(summary.totalWithdrawn, 2000.0);
      expect(summary.count, 2);
    });

    test('SavingSummary handles legacy response without deposited/withdrawn', () {
      final json = {
        'totalSaved': 4500.0,
        'count': 1,
      };

      final summary = SavingSummary.fromJson(json);

      expect(summary.totalSaved, 4500.0);
      expect(summary.totalDeposited, 4500.0);
      expect(summary.totalWithdrawn, 0.0);
      expect(summary.count, 1);
    });
  });
}
