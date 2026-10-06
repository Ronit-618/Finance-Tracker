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

        var repaid = await RepaidByLoanIdsAsync(loans.Select(l => l.Id));

        return loans.Select(l => MapToResponse(l, repaid.GetValueOrDefault(l.Id))).ToList();
    }

    [HttpGet("summary")]
    public async Task<ActionResult<LoanSummaryResponse>> GetSummary()
    {
        var openLoans = await _db.Loans
            .Where(l => !l.IsSettled)
            .ToListAsync();

        // Outstanding is net of repayments, so partial paybacks reduce what
        // the dashboard reports as owed.
        var repaid = await RepaidByLoanIdsAsync(openLoans.Select(l => l.Id));

        decimal Outstanding(Loan l) => Math.Max(0, l.Amount - repaid.GetValueOrDefault(l.Id));

        return new LoanSummaryResponse
        {
            TotalBorrowed = openLoans
                .Where(l => l.Direction == LoanDirection.Borrowed)
                .Sum(Outstanding),
            TotalLent = openLoans
                .Where(l => l.Direction == LoanDirection.Lent)
                .Sum(Outstanding),
            PayableOutstanding = openLoans
                .Where(l => l.Direction == LoanDirection.Borrowed)
                .Sum(Outstanding),
            ReceivableOutstanding = openLoans
                .Where(l => l.Direction == LoanDirection.Lent)
                .Sum(Outstanding),
            OpenCount = openLoans.Count
        };
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<LoanResponse>> GetById(int id)
    {
        var loan = await _db.Loans.FindAsync(id);
        if (loan is null) return NotFound();

        return MapToResponse(loan, await RepaidAsync(loan.Id));
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
        if (LoanPartyHelper.IsMe(fromPerson) || LoanPartyHelper.IsMe(toPerson))
            return BadRequest("Both cannot be you");

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

        return CreatedAtAction(nameof(GetById), new { id = loan.Id }, MapToResponse(loan, 0));
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<LoanResponse>> Update(int id, UpdateLoanRequest request)
    {
        var loan = await _db.Loans.FindAsync(id);
        if (loan is null) return NotFound();

        if (request.Amount <= 0)
            return BadRequest("Amount must be greater than 0");

        var alreadyRepaid = await RepaidAsync(loan.Id);
        if (request.Amount < alreadyRepaid)
            return BadRequest(
                $"Amount cannot be less than what has already been repaid ({alreadyRepaid:0.00})");

        var fromPerson = string.IsNullOrWhiteSpace(request.FromPerson) ? null : request.FromPerson.Trim();
        var toPerson = string.IsNullOrWhiteSpace(request.ToPerson) ? null : request.ToPerson.Trim();

        if (string.IsNullOrEmpty(fromPerson) && string.IsNullOrEmpty(toPerson))
            return BadRequest("Provide either FromPerson or ToPerson");
        if (!string.IsNullOrEmpty(fromPerson) && !string.IsNullOrEmpty(toPerson))
            return BadRequest("Provide only one of FromPerson or ToPerson, not both");
        if (LoanPartyHelper.IsMe(fromPerson) || LoanPartyHelper.IsMe(toPerson))
            return BadRequest("Both cannot be you");

        loan.Description = request.Description;
        loan.Amount = request.Amount;
        loan.FromPerson = fromPerson;
        loan.ToPerson = toPerson;
        loan.Direction = fromPerson != null ? LoanDirection.Borrowed : LoanDirection.Lent;
        if (request.ScreenshotPath is not null)
            loan.ScreenshotPath = request.ScreenshotPath;
        loan.IsCompleted = 1;
        loan.CreatedAt = DateTime.UtcNow;

        // Reducing the amount below what is already repaid would leave the loan
        // silently over-settled, so re-derive the settled flag.
        await RecalculateSettledAsync(loan);

        await _db.SaveChangesAsync();

        return MapToResponse(loan, alreadyRepaid);
    }

    [HttpGet("{id:int}/repayments")]
    public async Task<ActionResult<List<LoanRepaymentResponse>>> GetRepayments(int id)
    {
        if (!await _db.Loans.AnyAsync(l => l.Id == id)) return NotFound();

        var repayments = await _db.LoanRepayments
            .Where(r => r.LoanId == id)
            .OrderByDescending(r => r.Date)
            .ThenByDescending(r => r.Id)
            .ToListAsync();

        return repayments.Select(MapRepaymentToResponse).ToList();
    }

    [HttpGet("{id:int}/balance")]
    public async Task<ActionResult<LoanBalanceResponse>> GetBalance(int id)
    {
        var loan = await _db.Loans.FindAsync(id);
        if (loan is null) return NotFound();

        var repaid = await RepaidAsync(id);

        return new LoanBalanceResponse
        {
            LoanId = loan.Id,
            OriginalAmount = loan.Amount,
            AmountRepaid = repaid,
            Outstanding = Math.Max(0, loan.Amount - repaid),
            IsSettled = loan.IsSettled,
            SettledDate = loan.SettledDate
        };
    }

    [HttpPost("{id:int}/repayments")]
    public async Task<ActionResult<LoanRepaymentResponse>> AddRepayment(
        int id, CreateLoanRepaymentRequest request)
    {
        var loan = await _db.Loans.FindAsync(id);
        if (loan is null) return NotFound();

        if (request.Amount <= 0)
            return BadRequest("Repayment amount must be greater than 0");

        if (loan.IsSettled)
            return BadRequest("This loan is already settled. Reopen it before adding a repayment.");

        var repaid = await RepaidAsync(id);
        var outstanding = loan.Amount - repaid;

        if (request.Amount > outstanding)
            return BadRequest(
                $"Repayment cannot exceed the outstanding balance of {outstanding:0.00}");

        var repayment = new LoanRepayment
        {
            LoanId = loan.Id,
            Amount = request.Amount,
            Date = request.Date == default
                ? DateTime.UtcNow
                : DateHelper.NormalizeToUtc(request.Date),
            Note = string.IsNullOrWhiteSpace(request.Note) ? null : request.Note.Trim(),
            ScreenshotPath = request.ScreenshotPath,
            CreatedAt = DateTime.UtcNow
        };

        _db.LoanRepayments.Add(repayment);

        // Reaching zero settles the loan automatically.
        if (repaid + repayment.Amount >= loan.Amount)
        {
            loan.IsSettled = true;
            loan.SettledDate = DateTime.UtcNow;
            loan.CreatedAt = DateTime.UtcNow;
        }

        await _db.SaveChangesAsync();

        return CreatedAtAction(nameof(GetRepayments), new { id = loan.Id },
            MapRepaymentToResponse(repayment));
    }

    [HttpDelete("repayments/{repaymentId:int}")]
    public async Task<IActionResult> DeleteRepayment(int repaymentId)
    {
        var repayment = await _db.LoanRepayments.FindAsync(repaymentId);
        if (repayment is null) return NotFound();

        var loan = await _db.Loans.FindAsync(repayment.LoanId);
        _db.LoanRepayments.Remove(repayment);

        // Removing a repayment re-opens a loan that had auto-settled.
        if (loan is not null)
        {
            loan.IsSettled = false;
            loan.SettledDate = null;
            loan.CreatedAt = DateTime.UtcNow;
        }

        await _db.SaveChangesAsync();

        return NoContent();
    }

    [HttpPost("{id:int}/settle")]
    public async Task<ActionResult<LoanResponse>> Settle(int id)
    {
        var loan = await _db.Loans.FindAsync(id);
        if (loan is null) return NotFound();

        var repaid = await RepaidAsync(id);
        if (repaid > 0)
            return BadRequest(
                "This loan has recorded repayments, so it settles automatically. Delete the repayments to change it.");

        loan.IsSettled = !loan.IsSettled;
        loan.SettledDate = loan.IsSettled ? DateTime.UtcNow : null;
        loan.CreatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();

        return MapToResponse(loan, repaid);
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

    private async Task<decimal> RepaidAsync(int loanId) =>
        await _db.LoanRepayments
            .Where(r => r.LoanId == loanId)
            .SumAsync(r => (decimal?)r.Amount) ?? 0m;

    /// Re-derives the settled flag from the current amount and repayments so an
    /// edit that changes Amount can't leave a contradictory state.
    private async Task RecalculateSettledAsync(Loan loan)
    {
        var repaid = await RepaidAsync(loan.Id);

        if (repaid > 0)
        {
            var shouldSettle = repaid >= loan.Amount;
            if (shouldSettle != loan.IsSettled)
            {
                loan.IsSettled = shouldSettle;
                loan.SettledDate = shouldSettle ? loan.SettledDate ?? DateTime.UtcNow : null;
            }
        }
    }

    private async Task<Dictionary<int, decimal>> RepaidByLoanIdsAsync(IEnumerable<int> loanIds)
    {
        var ids = loanIds.ToList();
        if (ids.Count == 0) return new Dictionary<int, decimal>();

        return await _db.LoanRepayments
            .Where(r => ids.Contains(r.LoanId))
            .GroupBy(r => r.LoanId)
            .Select(g => new { LoanId = g.Key, Total = g.Sum(r => r.Amount) })
            .ToDictionaryAsync(x => x.LoanId, x => x.Total);
    }

    private static LoanRepaymentResponse MapRepaymentToResponse(LoanRepayment r) => new()
    {
        Id = r.Id,
        LoanId = r.LoanId,
        Amount = r.Amount,
        Date = r.Date,
        Note = r.Note,
        ScreenshotPath = r.ScreenshotPath,
        CreatedAt = r.CreatedAt,
        BsDate = NepaliDateService.AdToBs(r.Date)
    };

    private static LoanResponse MapToResponse(Loan l, decimal amountRepaid) => new()
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
        BsDate = NepaliDateService.AdToBs(l.Date),
        AmountRepaid = amountRepaid,
        Outstanding = Math.Max(0, l.Amount - amountRepaid)
    };
}
