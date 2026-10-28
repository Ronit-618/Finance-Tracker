class Saving {
  final int id;
  final int sn;
  final DateTime date;
  final String description;
  final double amount;
  final String category;
  final String type;
  final String? screenshotPath;
  final int isCompleted;
  final DateTime createdAt;
  final String? bsDate;

  Saving({
    required this.id,
    required this.sn,
    required this.date,
    required this.description,
    required this.amount,
    required this.category,
    this.type = 'Deposit',
    this.screenshotPath,
    required this.isCompleted,
    required this.createdAt,
    this.bsDate,
  });

  bool get isWithdrawal => type.toLowerCase() == 'withdrawal';
  bool get isDeposit => !isWithdrawal;

  factory Saving.fromJson(Map<String, dynamic> json) => Saving(
        id: json['id'] as int,
        sn: json['sn'] as int,
        date: DateTime.parse(json['date'] as String),
        description: (json['description'] as String?) ?? '',
        amount: (json['amount'] as num).toDouble(),
        category: (json['category'] as String?) ?? 'Saving',
        type: (json['type'] as String?) ?? 'Deposit',
        screenshotPath: json['screenshotPath'] as String?,
        isCompleted: json['isCompleted'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        bsDate: json['bsDate'] as String?,
      );
}

class SavingSummary {
  final double totalSaved;
  final double totalDeposited;
  final double totalWithdrawn;
  final int count;

  SavingSummary({
    required this.totalSaved,
    this.totalDeposited = 0.0,
    this.totalWithdrawn = 0.0,
    required this.count,
  });

  factory SavingSummary.fromJson(Map<String, dynamic> json) => SavingSummary(
        totalSaved: (json['totalSaved'] as num).toDouble(),
        totalDeposited: (json['totalDeposited'] as num?)?.toDouble() ??
            (json['totalSaved'] as num).toDouble(),
        totalWithdrawn: (json['totalWithdrawn'] as num?)?.toDouble() ?? 0.0,
        count: json['count'] as int,
      );
}
