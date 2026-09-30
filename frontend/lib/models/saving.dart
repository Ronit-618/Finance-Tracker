class Saving {
  final int id;
  final int sn;
  final DateTime date;
  final String description;
  final double amount;
  final String category;
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
    this.screenshotPath,
    required this.isCompleted,
    required this.createdAt,
    this.bsDate,
  });

  factory Saving.fromJson(Map<String, dynamic> json) => Saving(
        id: json['id'] as int,
        sn: json['sn'] as int,
        date: DateTime.parse(json['date'] as String),
        description: (json['description'] as String?) ?? '',
        amount: (json['amount'] as num).toDouble(),
        category: (json['category'] as String?) ?? 'Saving',
        screenshotPath: json['screenshotPath'] as String?,
        isCompleted: json['isCompleted'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        bsDate: json['bsDate'] as String?,
      );
}

class SavingSummary {
  final double totalSaved;
  final int count;

  SavingSummary({
    required this.totalSaved,
    required this.count,
  });

  factory SavingSummary.fromJson(Map<String, dynamic> json) => SavingSummary(
        totalSaved: (json['totalSaved'] as num).toDouble(),
        count: json['count'] as int,
      );
}
