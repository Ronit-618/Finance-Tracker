namespace FinanceTracker.Api.Models;

public class Bill
{
    public int Id { get; set; }
    public int SN { get; set; }
    public DateTime Date { get; set; }
    public string Description { get; set; } = string.Empty;
    public decimal Credit { get; set; }
    public decimal Debit { get; set; }
    public decimal Total { get; set; }
    public int EntryId { get; set; }
    public Entry Entry { get; set; } = null!;
    public DateTime CreatedAt { get; set; }
}
