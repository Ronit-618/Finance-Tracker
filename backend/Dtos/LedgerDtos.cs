namespace FinanceTracker.Api.Dtos;

/// <summary>
/// One row in the unified ledger. Every record the app can create — an Expense or
/// Income entry, a Saving, a Loan, or a Loan repayment — is flattened into this
/// single shape so the Transactions screen can list them all in one date-sorted
/// feed instead of being limited to v1 entries.
/// </summary>
public class LedgerItemResponse
{
    /// <summary>expense | income | saving | loan | repayment</summary>
    public string Kind { get; set; } = string.Empty;

    public int Id { get; set; }
    public int SN { get; set; }
    public DateTime Date { get; set; }
    public string Description { get; set; } = string.Empty;

    /// <summary>0 = expense, 1 = income. Only meaningful for the expense/income kinds.</summary>
    public int Type { get; set; }

    /// <summary>0 = debit, 1 = credit. Only meaningful for the expense/income kinds.</summary>
    public int PaymentType { get; set; }
    public int IsCompleted { get; set; }
    public DateTime CreatedAt { get; set; }

    /// <summary>
    /// Signed amount: positive for money that came in (income, a borrowed loan),
    /// negative for money that went out (expense, a saving set aside, a loan given,
    /// a repayment).
    /// </summary>
    public decimal Amount { get; set; }

    public string Category { get; set; } = string.Empty;
    public string? ScreenshotPath { get; set; }
    public string? BsDate { get; set; }

    // Loan-only detail.
    public string? FromPerson { get; set; }
    public string? ToPerson { get; set; }
    public string? Direction { get; set; }
    public bool IsSettled { get; set; }
    public decimal AmountRepaid { get; set; }
    public decimal Outstanding { get; set; }

    // Repayment-only detail.
    public int? LoanId { get; set; }
    public string? Note { get; set; }
}

/// <summary>
/// Cash-flow totals across every record type. Balance is what is actually
/// available: income in, minus expenses, savings set aside, loans given and
/// repayments, plus loans borrowed.
/// </summary>
public class LedgerSummaryResponse
{
    public decimal TotalIncome { get; set; }
    public decimal TotalExpense { get; set; }
    public decimal TotalSaved { get; set; }
    public decimal TotalBorrowed { get; set; }
    public decimal TotalLent { get; set; }
    public decimal TotalRepaid { get; set; }
    public decimal Balance { get; set; }
    public int TotalRecords { get; set; }
}
