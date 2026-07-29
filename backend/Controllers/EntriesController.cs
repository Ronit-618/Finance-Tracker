using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using FinanceTracker.Api.Data;
using FinanceTracker.Api.Dtos;
using FinanceTracker.Api.Models;

namespace FinanceTracker.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class EntryController : ControllerBase
{
    private readonly AppDbContext _db;

    public EntryController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<List<EntryResponse>>> GetAll(
        [FromQuery] DateTime? from,
        [FromQuery] DateTime? to,
        [FromQuery] EntryCategory? category,
        [FromQuery] EntryType? type,
        [FromQuery] PaymentType? paymentType)
    {
        var query = FilterQuery(from, to, category, type, paymentType);

        var entries = await query
            .OrderByDescending(e => e.Date)
            .ThenByDescending(e => e.SN)
            .ToListAsync();

        return entries.Select(MapToResponse).ToList();
    }

    [HttpGet("summary")]
    public async Task<ActionResult<EntrySummaryResponse>> GetSummary(
        [FromQuery] DateTime? from,
        [FromQuery] DateTime? to,
        [FromQuery] EntryCategory? category,
        [FromQuery] EntryType? type,
        [FromQuery] PaymentType? paymentType)
    {
        var query = FilterQuery(from, to, category, type, paymentType);

        var entries = await query.ToListAsync();

        return new EntrySummaryResponse
        {
            TotalEntries = entries.Count,
            TotalIncome = entries.Where(e => e.Type == EntryType.Income).Sum(e => e.Amount),
            TotalExpense = entries.Where(e => e.Type == EntryType.Expense).Sum(e => e.Amount),
            Balance = entries.Where(e => e.Type == EntryType.Income).Sum(e => e.Amount)
                     - entries.Where(e => e.Type == EntryType.Expense).Sum(e => e.Amount)
        };
    }

    [HttpGet("trial-balance")]
    public async Task<ActionResult<TrialBalanceResponse>> GetTrialBalance(
        [FromQuery] int year,
        [FromQuery] int month)
    {
        var from = new DateTime(year, month, 1);
        var to = from.AddMonths(1).AddDays(-1);

        var entries = await _db.Entries
            .Where(e => e.Date >= from && e.Date <= to)
            .ToListAsync();

        var items = entries
            .GroupBy(e => e.Category)
            .Select(g => new TrialBalanceItem
            {
                Category = g.Key.ToString(),
                DebitTotal = g.Where(e => e.PaymentType == PaymentType.Debit).Sum(e => e.Amount),
                CreditTotal = g.Where(e => e.PaymentType == PaymentType.Credit).Sum(e => e.Amount)
            })
            .OrderBy(i => i.Category)
            .ToList();

        return new TrialBalanceResponse
        {
            TotalDebit = items.Sum(i => i.DebitTotal),
            TotalCredit = items.Sum(i => i.CreditTotal),
            Items = items
        };
    }

    [HttpGet("by-category")]
    public async Task<ActionResult<List<CategoryTotalResponse>>> GetByCategory(
        [FromQuery] EntryType? type = null)
    {
        var query = _db.Entries.AsQueryable();

        if (type.HasValue)
            query = query.Where(e => e.Type == type.Value);

        var result = await query
            .GroupBy(e => e.Category)
            .Select(g => new CategoryTotalResponse
            {
                Category = g.Key.ToString(),
                Total = g.Sum(e => e.Amount),
                EntryCount = g.Count()
            })
            .OrderByDescending(r => r.Total)
            .ToListAsync();

        return result;
    }

    [HttpGet("grouped")]
    public async Task<ActionResult<List<EntryGroupResponse>>> GetGrouped(
        [FromQuery] string period = "month",
        [FromQuery] DateTime? from = null,
        [FromQuery] DateTime? to = null,
        [FromQuery] EntryCategory? category = null,
        [FromQuery] EntryType? type = null,
        [FromQuery] PaymentType? paymentType = null)
    {
        var query = FilterQuery(from, to, category, type, paymentType);
        var entries = await query.ToListAsync();

        IEnumerable<IGrouping<string, Entry>> groups = period.ToLower() switch
        {
            "day" => entries.GroupBy(e => e.Date.ToString("yyyy-MM-dd")),
            "year" => entries.GroupBy(e => e.Date.ToString("yyyy")),
            _ => entries.GroupBy(e => e.Date.ToString("yyyy-MM"))
        };

        return groups.OrderBy(g => g.Key).Select(g => new EntryGroupResponse
        {
            Period = g.Key,
            EntryCount = g.Count(),
            TotalIncome = g.Where(e => e.Type == EntryType.Income).Sum(e => e.Amount),
            TotalExpense = g.Where(e => e.Type == EntryType.Expense).Sum(e => e.Amount),
            Balance = g.Where(e => e.Type == EntryType.Income).Sum(e => e.Amount)
                    - g.Where(e => e.Type == EntryType.Expense).Sum(e => e.Amount)
        }).ToList();
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<EntryResponse>> GetById(int id)
    {
        var entry = await _db.Entries.FindAsync(id);
        if (entry is null) return NotFound();

        return MapToResponse(entry);
    }

    [HttpPost]
    public async Task<ActionResult<EntryResponse>> Create(CreateEntryRequest request)
    {
        var maxSN = await _db.Entries.MaxAsync(e => (int?)e.SN) ?? 0;

        var entry = new Entry
        {
            SN = maxSN + 1,
            Date = request.Date,
            Description = request.Description,
            Category = request.Category,
            Type = request.Type,
            PaymentType = request.Type == EntryType.Expense ? PaymentType.Debit : PaymentType.Credit,
            Amount = request.Amount,
            ScreenshotPath = request.ScreenshotPath,
            IsCompleted = 0,
            CreatedAt = DateTime.UtcNow
        };

        _db.Entries.Add(entry);
        await _db.SaveChangesAsync();

        var bill = new Bill
        {
            SN = entry.SN,
            Date = entry.Date,
            Description = entry.Description,
            Credit = entry.PaymentType == PaymentType.Credit ? entry.Amount : 0,
            Debit = entry.PaymentType == PaymentType.Debit ? entry.Amount : 0,
            Total = entry.PaymentType == PaymentType.Credit ? entry.Amount : -entry.Amount,
            EntryId = entry.Id,
            CreatedAt = DateTime.UtcNow
        };

        _db.Bills.Add(bill);
        await _db.SaveChangesAsync();

        var transaction = new Transaction
        {
            BillId = bill.Id,
            Income = bill.Total > 0 ? bill.Total : 0,
            Expense = bill.Total < 0 ? -bill.Total : 0
        };

        _db.Transactions.Add(transaction);
        await _db.SaveChangesAsync();

        return CreatedAtAction(nameof(GetById), new { id = entry.Id }, MapToResponse(entry));
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<EntryResponse>> Update(int id, UpdateEntryRequest request)
    {
        var entry = await _db.Entries.FindAsync(id);
        if (entry is null) return NotFound();

        entry.Description = request.Description;
        entry.Category = request.Category;
        entry.Type = request.Type;
        entry.PaymentType = request.Type == EntryType.Expense ? PaymentType.Debit : PaymentType.Credit;
        entry.Amount = request.Amount;
        if (request.ScreenshotPath is not null)
            entry.ScreenshotPath = request.ScreenshotPath;
        entry.IsCompleted = 1;
        entry.CreatedAt = DateTime.UtcNow;

        var bill = await _db.Bills.FirstOrDefaultAsync(b => b.EntryId == entry.Id);
        if (bill is not null)
        {
            bill.Description = entry.Description;
            bill.Credit = entry.PaymentType == PaymentType.Credit ? entry.Amount : 0;
            bill.Debit = entry.PaymentType == PaymentType.Debit ? entry.Amount : 0;
            bill.Total = entry.PaymentType == PaymentType.Credit ? entry.Amount : -entry.Amount;
            bill.CreatedAt = DateTime.UtcNow;
        }

        if (bill is not null)
        {
            var transaction = await _db.Transactions.FindAsync(bill.Id);
            if (transaction is not null)
            {
                transaction.Income = bill.Total > 0 ? bill.Total : 0;
                transaction.Expense = bill.Total < 0 ? -bill.Total : 0;
            }
        }

        await _db.SaveChangesAsync();

        return MapToResponse(entry);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var entry = await _db.Entries.FindAsync(id);
        if (entry is null) return NotFound();

        var bill = await _db.Bills.FirstOrDefaultAsync(b => b.EntryId == entry.Id);
        if (bill is not null)
        {
            var transaction = await _db.Transactions.FindAsync(bill.Id);
            if (transaction is not null)
                _db.Transactions.Remove(transaction);

            _db.Bills.Remove(bill);
        }

        _db.Entries.Remove(entry);
        await _db.SaveChangesAsync();

        return NoContent();
    }

    private IQueryable<Entry> FilterQuery(
        DateTime? from, DateTime? to,
        EntryCategory? category, EntryType? type, PaymentType? paymentType)
    {
        var query = _db.Entries.AsQueryable();

        if (from.HasValue)
            query = query.Where(e => e.Date >= from.Value.Date);
        if (to.HasValue)
            query = query.Where(e => e.Date <= to.Value.Date);
        if (category.HasValue)
            query = query.Where(e => e.Category == category.Value);
        if (type.HasValue)
            query = query.Where(e => e.Type == type.Value);
        if (paymentType.HasValue)
            query = query.Where(e => e.PaymentType == paymentType.Value);

        return query;
    }

    private static EntryResponse MapToResponse(Entry e) => new()
    {
        Id = e.Id,
        SN = e.SN,
        Date = e.Date,
        Description = e.Description,
        Category = e.Category,
        Type = e.Type,
        PaymentType = e.PaymentType,
        Amount = e.Amount,
        ScreenshotPath = e.ScreenshotPath,
        IsCompleted = e.IsCompleted,
        CreatedAt = e.CreatedAt
    };
}
