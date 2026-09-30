class Loan {
  final int id;
  final int sn;
  final DateTime date;
  final String description;
  final double amount;
  final String? fromPerson;
  final String? toPerson;

  /// 'Borrowed' = I owe this person. 'Lent' = this person owes me.
  final String direction;
  final String category;
  final bool isSettled;
  final DateTime? settledDate;
  final String? screenshotPath;
  final int isCompleted;
  final DateTime createdAt;
  final String? bsDate;

  Loan({
    required this.id,
    required this.sn,
    required this.date,
    required this.description,
    required this.amount,
    this.fromPerson,
    this.toPerson,
    required this.direction,
    required this.category,
    required this.isSettled,
    this.settledDate,
    this.screenshotPath,
    required this.isCompleted,
    required this.createdAt,
    this.bsDate,
  });

  bool get isBorrowed => direction.toLowerCase() == 'borrowed';

  /// The person this loan involves, regardless of direction.
  String? get person => fromPerson ?? toPerson;

  factory Loan.fromJson(Map<String, dynamic> json) => Loan(
        id: json['id'] as int,
        sn: json['sn'] as int,
        date: DateTime.parse(json['date'] as String),
        description: (json['description'] as String?) ?? '',
        amount: (json['amount'] as num).toDouble(),
        fromPerson: json['fromPerson'] as String?,
        toPerson: json['toPerson'] as String?,
        direction: (json['direction'] as String?) ?? 'Borrowed',
        category: (json['category'] as String?) ?? 'Loan',
        isSettled: json['isSettled'] as bool? ?? false,
        settledDate: json['settledDate'] == null
            ? null
            : DateTime.parse(json['settledDate'] as String),
        screenshotPath: json['screenshotPath'] as String?,
        isCompleted: json['isCompleted'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        bsDate: json['bsDate'] as String?,
      );
}

class LoanSummary {
  final double totalBorrowed;
  final double totalLent;
  final double payableOutstanding;
  final double receivableOutstanding;
  final int openCount;

  LoanSummary({
    required this.totalBorrowed,
    required this.totalLent,
    required this.payableOutstanding,
    required this.receivableOutstanding,
    required this.openCount,
  });

  factory LoanSummary.fromJson(Map<String, dynamic> json) => LoanSummary(
        totalBorrowed: (json['totalBorrowed'] as num).toDouble(),
        totalLent: (json['totalLent'] as num).toDouble(),
        payableOutstanding: (json['payableOutstanding'] as num).toDouble(),
        receivableOutstanding: (json['receivableOutstanding'] as num).toDouble(),
        openCount: json['openCount'] as int,
      );
}
