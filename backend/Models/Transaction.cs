namespace FinanceTracker.Api.Models;

public class Transaction
{
    public int BillId { get; set; }
    public decimal Income { get; set; }
    public decimal Expense { get; set; }
    public Bill Bill { get; set; } = null!;
}
