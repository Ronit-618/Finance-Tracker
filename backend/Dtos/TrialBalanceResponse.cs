namespace FinanceTracker.Api.Dtos;

public class TrialBalanceItem
{
    public string Category { get; set; } = string.Empty;
    public decimal DebitTotal { get; set; }
    public decimal CreditTotal { get; set; }
}

// Note: This app uses single-entry records (not true double-entry
// bookkeeping), so TotalDebit and TotalCredit will NOT necessarily be
// equal — that's expected and fine. This is a summary view, not a
// balanced ledger check.
public class TrialBalanceResponse
{
    public decimal TotalDebit { get; set; }
    public decimal TotalCredit { get; set; }
    public List<TrialBalanceItem> Items { get; set; } = [];
}
