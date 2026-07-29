class EntryGroup {
  final String period;
  final int entryCount;
  final double totalIncome;
  final double totalExpense;
  final double balance;

  EntryGroup({
    required this.period,
    required this.entryCount,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
  });

  factory EntryGroup.fromJson(Map<String, dynamic> json) => EntryGroup(
        period: json['period'],
        entryCount: json['entryCount'],
        totalIncome: (json['totalIncome'] as num).toDouble(),
        totalExpense: (json['totalExpense'] as num).toDouble(),
        balance: (json['balance'] as num).toDouble(),
      );
}
