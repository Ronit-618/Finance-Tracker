class CategoryTotal {
  final String category;
  final double total;
  final int entryCount;

  CategoryTotal({
    required this.category,
    required this.total,
    required this.entryCount,
  });

  factory CategoryTotal.fromJson(Map<String, dynamic> json) => CategoryTotal(
        category: json['category'] as String,
        total: (json['total'] as num).toDouble(),
        entryCount: json['entryCount'] as int,
      );
}
