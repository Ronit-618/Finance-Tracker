using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using FinanceTracker.Api.Data;
using FinanceTracker.Api.Dtos;
using FinanceTracker.Api.Models;
using FinanceTracker.Api.Services;

namespace FinanceTracker.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class LoanController : ControllerBase
{
    private readonly AppDbContext _db;

    public LoanController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<List<LoanResponse>>> GetAll(
        [FromQuery] DateTime? from,
        [FromQuery] DateTime? to,
        [FromQuery] int? bsYear,
        [FromQuery] int? bsMonth,
        [FromQuery] string? direction,
        [FromQuery] bool? isSettled,
        [FromQuery] string? person)
    {
        if (bsYear.HasValue && bsMonth.HasValue)
        {
            var (bsFrom, bsTo) = NepaliDateService.GetBsMonthAdRange(bsYear.Value, bsMonth.Value);
            from = bsFrom;
            to = bsTo;
        }

        var query = _db.Loans.AsQueryable();

        if (from.HasValue)
            query = query.Where(l => l.Date >= DateHelper.NormalizeToUtc(from.Value.Date));
        if (to.HasValue)
            query = query.Where(l => l.Date <= DateHelper.NormalizeToUtc(to.Value.Date));
        if (!string.IsNullOrEmpty(direction) && direction.ToLower() == "borrowed")
            query = query.Where(l => l.Direction == LoanDirection.Borrowed);
        else if (!string.IsNullOrEmpty(direction) && direction.ToLower() == "lent")
            query = query.Where(l => l.Direction == LoanDirection.Lent);
        if (isSettled.HasValue)
            query = query.Where(l => l.IsSettled == isSettled.Value);
        if (!string.IsNullOrEmpty(person))
            query = query.Where(l =>
                (l.FromPerson != null && l.FromPerson.Contains(person)) ||
                (l.ToPerson != null && l.ToPerson.Contains(person)));

        var loans = await query
            .OrderByDescending(l => l.Date)
            .ThenByDescending(l => l.SN)
            .ToListAsync();

        return loans.Select(MapToResponse).ToList();
    }

    [HttpGet("summary")]
    public async Task<ActionResult<LoanSummaryResponse>> GetSummary()
    {
        var openLoans = await _db.Loans
            .Where(l => !l.IsSettled)
            .ToListAsync();

        return new LoanSummaryResponse
        {
            TotalBorrowed = openLoans
                .Where(l => l.Direction == LoanDirection.Borrowed)
                .Sum(l => l.Amount),
            TotalLent = openLoans
                .Where(l => l.Direction == LoanDirection.Lent)
                .Sum(l => l.Amount),
            PayableOutstanding = openLoans
                .Where(l => l.Direction == LoanDirection.Borrowed)
                .Sum(l => l.Amount),
            ReceivableOutstanding = openLoans
                .Where(l => l.Direction == LoanDirection.Lent)
                .Sum(l => l.Amount),
            OpenCount = openLoans.Count
        };
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<LoanResponse>> GetById(int id)
    {
        var loan = await _db.Loans.FindAsync(id);
        if (loan is null) return NotFound();

        return MapToResponse(loan);
    }

    [HttpPost]
    public async Task<ActionResult<LoanResponse>> Create(CreateLoanRequest request)
    {
        if (request.Amount <= 0)
            return BadRequest("Amount must be greater than 0");

        var fromPerson = string.IsNullOrWhiteSpace(request.FromPerson) ? null : request.FromPerson.Trim();
        var toPerson = string.IsNullOrWhiteSpace(request.ToPerson) ? null : request.ToPerson.Trim();

        if (string.IsNullOrEmpty(fromPerson) && string.IsNullOrEmpty(toPerson))
            return BadRequest("Provide either FromPerson or ToPerson");
        if (!string.IsNullOrEmpty(fromPerson) && !string.IsNullOrEmpty(toPerson))
            return BadRequest("Provide only one of FromPerson or ToPerson, not both");

        var direction = fromPerson != null ? LoanDirection.Borrowed : LoanDirection.Lent;

        var maxSN = await _db.Loans.MaxAsync(l => (int?)l.SN) ?? 0;

        var loan = new Loan
        {
            SN = maxSN + 1,
            Date = DateHelper.NormalizeToUtc(request.Date),
            Description = request.Description,
            Amount = request.Amount,
            FromPerson = fromPerson,
            ToPerson = toPerson,
            Direction = direction,
            Category = "Loan",
            IsSettled = false,
            ScreenshotPath = request.ScreenshotPath,
            IsCompleted = 0,
            CreatedAt = DateTime.UtcNow
        };

        _db.Loans.Add(loan);
        await _db.SaveChangesAsync();

        return CreatedAtAction(nameof(GetById), new { id = loan.Id }, MapToResponse(loan));
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<LoanResponse>> Update(int id, UpdateLoanRequest request)
    {
        var loan = await _db.Loans.FindAsync(id);
        if (loan is null) return NotFound();

        if (request.Amount <= 0)
            return BadRequest("Amount must be greater than 0");

        var fromPerson = string.IsNullOrWhiteSpace(request.FromPerson) ? null : request.FromPerson.Trim();
        var toPerson = string.IsNullOrWhiteSpace(request.ToPerson) ? null : request.ToPerson.Trim();

        if (string.IsNullOrEmpty(fromPerson) && string.IsNullOrEmpty(toPerson))
            return BadRequest("Provide either FromPerson or ToPerson");
        if (!string.IsNullOrEmpty(fromPerson) && !string.IsNullOrEmpty(toPerson))
            return BadRequest("Provide only one of FromPerson or ToPerson, not both");

        loan.Description = request.Description;
        loan.Amount = request.Amount;
        loan.FromPerson = fromPerson;
        loan.ToPerson = toPerson;
        loan.Direction = fromPerson != null ? LoanDirection.Borrowed : LoanDirection.Lent;
        if (request.ScreenshotPath is not null)
            loan.ScreenshotPath = request.ScreenshotPath;
        loan.IsCompleted = 1;
        loan.CreatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();

        return MapToResponse(loan);
    }

    [HttpPost("{id:int}/settle")]
    public async Task<ActionResult<LoanResponse>> Settle(int id)
    {
        var loan = await _db.Loans.FindAsync(id);
        if (loan is null) return NotFound();

        loan.IsSettled = !loan.IsSettled;
        loan.SettledDate = loan.IsSettled ? DateTime.UtcNow : null;
        loan.CreatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();

        return MapToResponse(loan);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var loan = await _db.Loans.FindAsync(id);
        if (loan is null) return NotFound();

        _db.Loans.Remove(loan);
        await _db.SaveChangesAsync();

        return NoContent();
    }

    private static LoanResponse MapToResponse(Loan l) => new()
    {
        Id = l.Id,
        SN = l.SN,
        Date = l.Date,
        Description = l.Description,
        Amount = l.Amount,
        FromPerson = l.FromPerson,
        ToPerson = l.ToPerson,
        Direction = l.Direction.ToString(),
        Category = l.Category,
        IsSettled = l.IsSettled,
        SettledDate = l.SettledDate,
        ScreenshotPath = l.ScreenshotPath,
        IsCompleted = l.IsCompleted,
        CreatedAt = l.CreatedAt,
        BsDate = NepaliDateService.AdToBs(l.Date)
    };
}
