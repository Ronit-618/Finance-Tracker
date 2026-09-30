using FinanceTracker.Api.Models;

namespace FinanceTracker.Api.Dtos;

public class CreateLoanRequest
{
    public DateTime Date { get; set; }
    public string Description { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string? FromPerson { get; set; }
    public string? ToPerson { get; set; }
    public string? ScreenshotPath { get; set; }
}

public class UpdateLoanRequest
{
    public string Description { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string? FromPerson { get; set; }
    public string? ToPerson { get; set; }
    public string? ScreenshotPath { get; set; }
}

public class LoanResponse
{
    public int Id { get; set; }
    public int SN { get; set; }
    public DateTime Date { get; set; }
    public string Description { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string? FromPerson { get; set; }
    public string? ToPerson { get; set; }
    public string Direction { get; set; } = string.Empty;
    public string Category { get; set; } = "Loan";
    public bool IsSettled { get; set; }
    public DateTime? SettledDate { get; set; }
    public string? ScreenshotPath { get; set; }
    public int IsCompleted { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? BsDate { get; set; }
}

public class LoanSummaryResponse
{
    public decimal TotalBorrowed { get; set; }
    public decimal TotalLent { get; set; }
    public decimal PayableOutstanding { get; set; }
    public decimal ReceivableOutstanding { get; set; }
    public int OpenCount { get; set; }
}
