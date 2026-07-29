class TrialBalanceItem {
  final String category;
  final double debitTotal;
  final double creditTotal;

  TrialBalanceItem({
    required this.category,
    required this.debitTotal,
    required this.creditTotal,
  });

  factory TrialBalanceItem.fromJson(Map<String, dynamic> json) => TrialBalanceItem(
        category: json['category'] as String,
        debitTotal: (json['debitTotal'] as num).toDouble(),
        creditTotal: (json['creditTotal'] as num).toDouble(),
      );
}

class TrialBalanceResponse {
  final double totalDebit;
  final double totalCredit;
  final List<TrialBalanceItem> items;

  TrialBalanceResponse({
    required this.totalDebit,
    required this.totalCredit,
    required this.items,
  });

  factory TrialBalanceResponse.fromJson(Map<String, dynamic> json) => TrialBalanceResponse(
        totalDebit: (json['totalDebit'] as num).toDouble(),
        totalCredit: (json['totalCredit'] as num).toDouble(),
        items: (json['items'] as List<dynamic>)
            .map((e) => TrialBalanceItem.fromJson(e))
            .toList(),
      );
}
