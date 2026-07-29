namespace FinanceTracker.Api.Dtos;

public class BillResponse
{
    public int Id { get; set; }
    public int SN { get; set; }
    public DateTime Date { get; set; }
    public string Description { get; set; } = string.Empty;
    public decimal Credit { get; set; }
    public decimal Debit { get; set; }
    public decimal Total { get; set; }
    public decimal Balance { get; set; }
    public DateTime CreatedAt { get; set; }
}
