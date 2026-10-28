namespace FinanceTracker.Api.Models;

public enum SavingType
{
    Deposit,
    Withdrawal
}

public class Saving
{
    public int Id { get; set; }
    public int SN { get; set; }
    public DateTime Date { get; set; }
    public string Description { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string Category { get; set; } = "Saving";
    public SavingType Type { get; set; } = SavingType.Deposit;
    public string? ScreenshotPath { get; set; }
    public int IsCompleted { get; set; }
    public DateTime CreatedAt { get; set; }
}
