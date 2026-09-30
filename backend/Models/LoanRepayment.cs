namespace FinanceTracker.Api.Models;

/// <summary>
/// A single repayment against a Loan. Multiple repayments may exist per loan;
/// outstanding = Loan.Amount - SUM(repayments).
/// </summary>
public class LoanRepayment
{
    public int Id { get; set; }
    public int LoanId { get; set; }
    public Loan Loan { get; set; } = null!;
    public decimal Amount { get; set; }
    public DateTime Date { get; set; }
    public string? Note { get; set; }
    public string? ScreenshotPath { get; set; }
    public DateTime CreatedAt { get; set; }
}
