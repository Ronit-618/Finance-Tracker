namespace FinanceTracker.Api.Dtos;

public class PositionSummaryResponse
{
    public decimal TotalSavings { get; set; }
    public decimal TotalBorrowed { get; set; }
    public decimal TotalLent { get; set; }
    public decimal PayableOutstanding { get; set; }
    public decimal ReceivableOutstanding { get; set; }
}
