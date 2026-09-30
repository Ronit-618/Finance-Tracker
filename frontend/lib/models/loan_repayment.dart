/// A single repayment against a Loan. Several may exist per loan.
class LoanRepayment {
  final int id;
  final int loanId;
  final double amount;
  final DateTime date;
  final String? note;
  final String? screenshotPath;
  final DateTime createdAt;
  final String? bsDate;

  LoanRepayment({
    required this.id,
    required this.loanId,
    required this.amount,
    required this.date,
    this.note,
    this.screenshotPath,
    required this.createdAt,
    this.bsDate,
  });

  factory LoanRepayment.fromJson(Map<String, dynamic> json) => LoanRepayment(
        id: json['id'] as int,
        loanId: json['loanId'] as int,
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        note: json['note'] as String?,
        screenshotPath: json['screenshotPath'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        bsDate: json['bsDate'] as String?,
      );
}
