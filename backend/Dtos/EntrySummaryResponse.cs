namespace FinanceTracker.Api.Dtos;

public class EntrySummaryResponse
{
    public int TotalEntries { get; set; }
    public decimal TotalIncome { get; set; }
    public decimal TotalExpense { get; set; }
    public decimal Balance { get; set; }
}
