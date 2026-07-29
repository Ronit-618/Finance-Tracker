using FinanceTracker.Api.Models;

namespace FinanceTracker.Api.Dtos;

public class CreateEntryRequest
{
    public DateTime Date { get; set; }
    public string Description { get; set; } = string.Empty;
    public EntryCategory Category { get; set; }
    public EntryType Type { get; set; }
    public decimal Amount { get; set; }
    public string? ScreenshotPath { get; set; }
}
