using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using FinanceTracker.Api.Data;
using FinanceTracker.Api.Dtos;
using FinanceTracker.Api.Models;
using FinanceTracker.Api.Services;

namespace FinanceTracker.Api.Controllers;

/// <summary>
/// Unified ledger over every record type. The Transactions screen reads this so
/// expenses, income, savings, loans and repayments all appear in one feed, and
/// the dashboard reads the summary for a balance that reflects cash actually
/// moving in and out.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class LedgerController : ControllerBase
{
    private readonly AppDbContext _db;

    public LedgerController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<List<LedgerItemResponse>>> GetAll(
        [FromQuery] DateTime? from,
        [FromQuery] DateTime? to,
        [FromQuery] int? bsYear,
        [FromQuery] int? bsMonth)
    {
        if (bsYear.HasValue && bsMonth.HasValue)
        {
            var (bsFrom, bsTo) = NepaliDateService.GetBsMonthAdRange(bsYear.Value, bsMonth.Value);
            from = bsFrom;
            to = bsTo;
        }

        var fromUtc = from.HasValue ? DateHelper.NormalizeToUtc(from.Value.Date) : (DateTime?)null;
        var toUtc = to.HasValue ? DateHelper.NormalizeToUtc(to.Value.Date) : (DateTime?)null;

        var entries = await _db.Entries.ToListAsync();
        var savings = await _db.Savings.ToListAsync();
        var loans = await _db.Loans.ToListAsync();
        var repayments = await _db.LoanRepayments.ToListAsync();

        var repaidByLoan = await _db.LoanRepayments
            .GroupBy(r => r.LoanId)
            .Select(g => new { LoanId = g.Key, Total = g.Sum(r => r.Amount) })
            .ToListAsync();
        var repaidLookup = repaidByLoan.ToDictionary(x => x.LoanId, x => x.Total);

        var items = new List<LedgerItemResponse>();

        foreach (var e in entries)
        {
            var isExpense = e.Type == EntryType.Expense;
            items.Add(new LedgerItemResponse
            {
                Kind = isExpense ? "expense" : "income",
                Id = e.Id,
                SN = e.SN,
                Date = e.Date,
                Description = e.Description,
                Amount = isExpense ? -e.Amount : e.Amount,
                Category = e.Category.ToString(),
                ScreenshotPath = e.ScreenshotPath,
                BsDate = NepaliDateService.AdToBs(e.Date),
                Type = isExpense ? 0 : 1,
                PaymentType = e.PaymentType == PaymentType.Debit ? 0 : 1,
                IsCompleted = e.IsCompleted,
                CreatedAt = e.CreatedAt
            });
        }

        foreach (var s in savings)
        {
            items.Add(new LedgerItemResponse
            {
                Kind = "saving",
                Id = s.Id,
                SN = s.SN,
                Date = s.Date,
                Description = s.Description,
                Amount = -s.Amount,
                Category = s.Category,
                ScreenshotPath = s.ScreenshotPath,
                BsDate = NepaliDateService.AdToBs(s.Date),
                IsCompleted = s.IsCompleted,
                CreatedAt = s.CreatedAt
            });
        }

        foreach (var l in loans)
        {
            var repaid = repaidLookup.GetValueOrDefault(l.Id);
            var isBorrowed = l.Direction == LoanDirection.Borrowed;
            items.Add(new LedgerItemResponse
            {
                Kind = "loan",
                Id = l.Id,
                SN = l.SN,
                Date = l.Date,
                Description = l.Description,
                Amount = isBorrowed ? l.Amount : -l.Amount,
                Category = l.Category,
                ScreenshotPath = l.ScreenshotPath,
                BsDate = NepaliDateService.AdToBs(l.Date),
                IsCompleted = l.IsCompleted,
                CreatedAt = l.CreatedAt,
                FromPerson = l.FromPerson,
                ToPerson = l.ToPerson,
                Direction = l.Direction.ToString(),
                IsSettled = l.IsSettled,
                AmountRepaid = repaid,
                Outstanding = Math.Max(0, l.Amount - repaid)
            });
        }

        foreach (var r in repayments)
        {
            items.Add(new LedgerItemResponse
            {
                Kind = "repayment",
                Id = r.Id,
                Date = r.Date,
                Description = string.IsNullOrWhiteSpace(r.Note) ? "Loan repayment" : r.Note!,
                Amount = -r.Amount,
                Category = "Repayment",
                ScreenshotPath = r.ScreenshotPath,
                BsDate = NepaliDateService.AdToBs(r.Date),
                CreatedAt = r.CreatedAt,
                LoanId = r.LoanId,
                Note = r.Note
            });
        }

        if (fromUtc.HasValue)
            items = items.Where(i => i.Date >= fromUtc.Value).ToList();
        if (toUtc.HasValue)
            items = items.Where(i => i.Date <= toUtc.Value).ToList();

        return items
            .OrderByDescending(i => i.Date)
            .ThenByDescending(i => i.Id)
            .ToList();
    }

    [HttpGet("summary")]
    public async Task<ActionResult<LedgerSummaryResponse>> GetSummary(
        [FromQuery] DateTime? from,
        [FromQuery] DateTime? to,
        [FromQuery] int? bsYear,
        [FromQuery] int? bsMonth)
    {
        if (bsYear.HasValue && bsMonth.HasValue)
        {
            var (bsFrom, bsTo) = NepaliDateService.GetBsMonthAdRange(bsYear.Value, bsMonth.Value);
            from = bsFrom;
            to = bsTo;
        }

        var fromUtc = from.HasValue ? DateHelper.NormalizeToUtc(from.Value.Date) : (DateTime?)null;
        var toUtc = to.HasValue ? DateHelper.NormalizeToUtc(to.Value.Date) : (DateTime?)null;

        var entries = await _db.Entries.ToListAsync();
        var savings = await _db.Savings.ToListAsync();
        var loans = await _db.Loans.ToListAsync();
        var repayments = await _db.LoanRepayments.ToListAsync();

        var totalIncome = entries.Where(e => e.Type == EntryType.Income).Sum(e => e.Amount);
        var totalExpense = entries.Where(e => e.Type == EntryType.Expense).Sum(e => e.Amount);
        var totalSaved = savings.Sum(s => s.Amount);
        var totalBorrowed = loans.Where(l => l.Direction == LoanDirection.Borrowed).Sum(l => l.Amount);
        var totalLent = loans.Where(l => l.Direction == LoanDirection.Lent).Sum(l => l.Amount);
        var totalRepaid = repayments.Sum(r => r.Amount);

        // Repayments split by the direction of the parent loan: money paid out to
        // others (borrowed) versus money received back (lent).
        var borrowedLoanIds = loans
            .Where(l => l.Direction == LoanDirection.Borrowed)
            .Select(l => l.Id)
            .ToHashSet();
        var repaidOut = repayments.Where(r => borrowedLoanIds.Contains(r.LoanId)).ToList();
        var totalRepaidOut = repaidOut.Sum(r => r.Amount);

        return new LedgerSummaryResponse
        {
            TotalIncome = totalIncome,
            TotalExpense = totalExpense,
            TotalSaved = totalSaved,
            TotalBorrowed = totalBorrowed,
            TotalLent = totalLent,
            TotalRepaid = totalRepaid,
            TotalRepaidOut = totalRepaidOut,
            RepaidOutCount = repaidOut.Count,
            Balance = totalIncome - totalExpense - totalSaved - totalLent - totalRepaid + totalBorrowed,
            TotalRecords = entries.Count + savings.Count + loans.Count + repayments.Count
        };
    }
}
