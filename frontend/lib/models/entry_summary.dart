class EntrySummary {
  final int totalEntries;
  final double totalIncome;
  final double totalExpense;
  final double balance;

  EntrySummary({
    required this.totalEntries,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
  });

  factory EntrySummary.fromJson(Map<String, dynamic> json) => EntrySummary(
        totalEntries: json['totalEntries'],
        totalIncome: (json['totalIncome'] as num).toDouble(),
        totalExpense: (json['totalExpense'] as num).toDouble(),
        balance: (json['balance'] as num).toDouble(),
      );
}
