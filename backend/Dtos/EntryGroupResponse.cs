namespace FinanceTracker.Api.Dtos;

public class EntryGroupResponse
{
    public string Period { get; set; } = string.Empty;
    public int EntryCount { get; set; }
    public decimal TotalIncome { get; set; }
    public decimal TotalExpense { get; set; }
    public decimal Balance { get; set; }
}
