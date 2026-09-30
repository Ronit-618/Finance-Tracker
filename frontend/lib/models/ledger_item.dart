/// One row in the unified ledger. Every record the app can create — an Expense or
/// Income entry, a Saving, a Loan, or a Loan repayment — is flattened into this
/// shape so the Transactions screen can list them all in a single date-sorted feed.
class LedgerItem {
  final String kind;
  final int id;
  final int sn;
  final DateTime date;
  final String description;

  /// Signed: positive for money in (income, a borrowed loan), negative for money
  /// out (expense, a saving set aside, a loan given, a repayment).
  final double amount;

  final String category;
  final String? subCategory;
  final String? screenshotPath;
  final String? bsDate;

  final String? fromPerson;
  final String? toPerson;
  final String? direction;
  final bool isSettled;
  final double amountRepaid;
  final double outstanding;

  final int type;
  final int paymentType;
  final int isCompleted;
  final DateTime createdAt;

  final int? loanId;
  final String? note;

  LedgerItem({
    required this.kind,
    required this.id,
    required this.sn,
    required this.date,
    required this.description,
    required this.amount,
    required this.category,
    this.subCategory,
    this.screenshotPath,
    this.bsDate,
    this.fromPerson,
    this.toPerson,
    this.direction,
    this.isSettled = false,
    this.amountRepaid = 0,
    this.outstanding = 0,
    this.type = 0,
    this.paymentType = 0,
    this.isCompleted = 0,
    required this.createdAt,
    this.loanId,
    this.note,
  });

  bool get isMoneyIn => amount >= 0;

  /// The person this loan involves, regardless of direction.
  String? get person => fromPerson ?? toPerson;

  factory LedgerItem.fromJson(Map<String, dynamic> json) => LedgerItem(
        kind: json['kind'] as String,
        id: json['id'] as int,
        sn: json['sn'] as int? ?? 0,
        date: DateTime.parse(json['date'] as String),
        description: (json['description'] as String?) ?? '',
        amount: (json['amount'] as num).toDouble(),
        category: (json['category'] as String?) ?? '',
        subCategory: json['subCategory'] as String?,
        screenshotPath: json['screenshotPath'] as String?,
        bsDate: json['bsDate'] as String?,
        fromPerson: json['fromPerson'] as String?,
        toPerson: json['toPerson'] as String?,
        direction: json['direction'] as String?,
        isSettled: json['isSettled'] as bool? ?? false,
        amountRepaid: (json['amountRepaid'] as num?)?.toDouble() ?? 0,
        outstanding: (json['outstanding'] as num?)?.toDouble() ?? 0,
        type: json['type'] as int? ?? 0,
        paymentType: json['paymentType'] as int? ?? 0,
        isCompleted: json['isCompleted'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        loanId: json['loanId'] as int?,
        note: json['note'] as String?,
      );
}

/// Cash-flow totals across every record type.
class LedgerSummary {
  final double totalIncome;
  final double totalExpense;
  final double totalSaved;
  final double totalBorrowed;
  final double totalLent;
  final double totalRepaid;
  final double totalRepaidOut;
  final int repaidOutCount;
  final double balance;
  final int totalRecords;

  LedgerSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.totalSaved,
    required this.totalBorrowed,
    required this.totalLent,
    required this.totalRepaid,
    required this.totalRepaidOut,
    required this.repaidOutCount,
    required this.balance,
    required this.totalRecords,
  });

  /// Total principal of all loans, used as the "Loan" slice of the pie chart.
  double get totalLoan => totalBorrowed + totalLent;

  factory LedgerSummary.fromJson(Map<String, dynamic> json) => LedgerSummary(
        totalIncome: (json['totalIncome'] as num).toDouble(),
        totalExpense: (json['totalExpense'] as num).toDouble(),
        totalSaved: (json['totalSaved'] as num).toDouble(),
        totalBorrowed: (json['totalBorrowed'] as num).toDouble(),
        totalLent: (json['totalLent'] as num).toDouble(),
        totalRepaid: (json['totalRepaid'] as num).toDouble(),
        totalRepaidOut: (json['totalRepaidOut'] as num?)?.toDouble() ?? 0,
        repaidOutCount: json['repaidOutCount'] as int? ?? 0,
        balance: (json['balance'] as num).toDouble(),
        totalRecords: json['totalRecords'] as int? ?? 0,
      );
}
