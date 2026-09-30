namespace FinanceTracker.Api.Models;

public enum LoanDirection
{
    Borrowed,
    Lent
}

public class Loan
{
    public int Id { get; set; }
    public int SN { get; set; }
    public DateTime Date { get; set; }
    public string Description { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string? FromPerson { get; set; }
    public string? ToPerson { get; set; }
    public LoanDirection Direction { get; set; }
    public string Category { get; set; } = "Loan";
    public bool IsSettled { get; set; }
    public DateTime? SettledDate { get; set; }
    public string? ScreenshotPath { get; set; }
    public int IsCompleted { get; set; }
    public DateTime CreatedAt { get; set; }
}
