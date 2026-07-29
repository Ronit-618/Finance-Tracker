class Entry {
  final int id;
  final int sn;
  final DateTime date;
  final String description;
  final int category;
  final int type;
  final int paymentType;
  final double amount;
  final String? screenshotPath;
  final int isCompleted;
  final DateTime createdAt;

  Entry({
    required this.id,
    required this.sn,
    required this.date,
    required this.description,
    required this.category,
    required this.type,
    required this.paymentType,
    required this.amount,
    this.screenshotPath,
    required this.isCompleted,
    required this.createdAt,
  });

  factory Entry.fromJson(Map<String, dynamic> json) => Entry(
        id: json['id'] as int,
        sn: json['sn'] as int,
        date: DateTime.parse(json['date'] as String),
        description: (json['description'] as String?) ?? '',
        category: json['category'] as int,
        type: json['type'] as int,
        paymentType: json['paymentType'] as int,
        amount: (json['amount'] as num).toDouble(),
        screenshotPath: json['screenshotPath'] as String?,
        isCompleted: json['isCompleted'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String().split('T')[0],
        'description': description,
        'category': category,
        'type': type,
        'amount': amount,
        'screenshotPath': screenshotPath,
      };
}