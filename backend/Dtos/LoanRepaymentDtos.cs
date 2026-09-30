using FinanceTracker.Api.Models;

namespace FinanceTracker.Api.Dtos;

public class CreateLoanRepaymentRequest
{
    public decimal Amount { get; set; }
    public DateTime Date { get; set; }
    public string? Note { get; set; }
    public string? ScreenshotPath { get; set; }
}

public class LoanRepaymentResponse
{
    public int Id { get; set; }
    public int LoanId { get; set; }
    public decimal Amount { get; set; }
    public DateTime Date { get; set; }
    public string? Note { get; set; }
    public string? ScreenshotPath { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? BsDate { get; set; }
}

/// Outstanding balances for one loan, recomputed from its repayments.
public class LoanBalanceResponse
{
    public int LoanId { get; set; }
    public decimal OriginalAmount { get; set; }
    public decimal AmountRepaid { get; set; }
    public decimal Outstanding { get; set; }
    public bool IsSettled { get; set; }
    public DateTime? SettledDate { get; set; }
}
