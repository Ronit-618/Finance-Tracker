namespace FinanceTracker.Api.Models;

public enum EntryCategory
{
    PersonalPayment,
    BillSharing,
    Loan,
    Income
}

public enum EntryType
{
    Expense,
    Income
}

public enum PaymentType
{
    Debit,
    Credit
}

public class Entry
{
    public int Id { get; set; }
    public int SN { get; set; }
    public DateTime Date { get; set; }
    public string Description { get; set; } = string.Empty;
    public EntryCategory Category { get; set; }
    public EntryType Type { get; set; }
    public PaymentType PaymentType { get; set; }
    public decimal Amount { get; set; }
    public string? ScreenshotPath { get; set; }
    public int IsCompleted { get; set; }
    public DateTime CreatedAt { get; set; }
}
