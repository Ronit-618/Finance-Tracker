namespace FinanceTracker.Api.Dtos;

public class TransactionResponse
{
    public int BillId { get; set; }
    public decimal Income { get; set; }
    public decimal Expense { get; set; }
}
