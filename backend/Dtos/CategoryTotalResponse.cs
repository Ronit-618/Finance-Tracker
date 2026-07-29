namespace FinanceTracker.Api.Dtos;

public class CategoryTotalResponse
{
    public string Category { get; set; } = string.Empty;
    public decimal Total { get; set; }
    public int EntryCount { get; set; }
}
