namespace FinanceTracker.Api.Dtos;

public class CreateSavingRequest
{
    public DateTime Date { get; set; }
    public string Description { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string? ScreenshotPath { get; set; }
}

public class UpdateSavingRequest
{
    public string Description { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string? ScreenshotPath { get; set; }
}

public class SavingResponse
{
    public int Id { get; set; }
    public int SN { get; set; }
    public DateTime Date { get; set; }
    public string Description { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string Category { get; set; } = "Saving";
    public string? ScreenshotPath { get; set; }
    public int IsCompleted { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? BsDate { get; set; }
}

public class SavingSummaryResponse
{
    public decimal TotalSaved { get; set; }
    public int Count { get; set; }
}
