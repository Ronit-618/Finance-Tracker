using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using FinanceTracker.Api.Data;
using FinanceTracker.Api.Dtos;
using FinanceTracker.Api.Models;
using FinanceTracker.Api.Services;

namespace FinanceTracker.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SavingController : ControllerBase
{
    private readonly AppDbContext _db;

    public SavingController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<List<SavingResponse>>> GetAll(
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

        var query = _db.Savings.AsQueryable();

        if (from.HasValue)
            query = query.Where(s => s.Date >= DateHelper.NormalizeToUtc(from.Value.Date));
        if (to.HasValue)
            query = query.Where(s => s.Date <= DateHelper.NormalizeToUtc(to.Value.Date));

        var savings = await query
            .OrderByDescending(s => s.Date)
            .ThenByDescending(s => s.SN)
            .ToListAsync();

        return savings.Select(MapToResponse).ToList();
    }

    [HttpGet("summary")]
    public async Task<ActionResult<SavingSummaryResponse>> GetSummary(
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

        var query = _db.Savings.AsQueryable();

        if (from.HasValue)
            query = query.Where(s => s.Date >= DateHelper.NormalizeToUtc(from.Value.Date));
        if (to.HasValue)
            query = query.Where(s => s.Date <= DateHelper.NormalizeToUtc(to.Value.Date));

        var savings = await query.ToListAsync();

        return new SavingSummaryResponse
        {
            TotalSaved = savings.Sum(s => s.Amount),
            Count = savings.Count
        };
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<SavingResponse>> GetById(int id)
    {
        var saving = await _db.Savings.FindAsync(id);
        if (saving is null) return NotFound();

        return MapToResponse(saving);
    }

    [HttpPost]
    public async Task<ActionResult<SavingResponse>> Create(CreateSavingRequest request)
    {
        if (request.Amount <= 0)
            return BadRequest("Amount must be greater than 0");

        var maxSN = await _db.Savings.MaxAsync(s => (int?)s.SN) ?? 0;

        var saving = new Saving
        {
            SN = maxSN + 1,
            Date = DateHelper.NormalizeToUtc(request.Date),
            Description = request.Description,
            Amount = request.Amount,
            Category = "Saving",
            ScreenshotPath = request.ScreenshotPath,
            IsCompleted = 0,
            CreatedAt = DateTime.UtcNow
        };

        _db.Savings.Add(saving);
        await _db.SaveChangesAsync();

        return CreatedAtAction(nameof(GetById), new { id = saving.Id }, MapToResponse(saving));
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<SavingResponse>> Update(int id, UpdateSavingRequest request)
    {
        var saving = await _db.Savings.FindAsync(id);
        if (saving is null) return NotFound();

        if (request.Amount <= 0)
            return BadRequest("Amount must be greater than 0");

        saving.Description = request.Description;
        saving.Amount = request.Amount;
        if (request.ScreenshotPath is not null)
            saving.ScreenshotPath = request.ScreenshotPath;
        saving.IsCompleted = 1;
        saving.CreatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();

        return MapToResponse(saving);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var saving = await _db.Savings.FindAsync(id);
        if (saving is null) return NotFound();

        _db.Savings.Remove(saving);
        await _db.SaveChangesAsync();

        return NoContent();
    }

    private static SavingResponse MapToResponse(Saving s) => new()
    {
        Id = s.Id,
        SN = s.SN,
        Date = s.Date,
        Description = s.Description,
        Amount = s.Amount,
        Category = s.Category,
        ScreenshotPath = s.ScreenshotPath,
        IsCompleted = s.IsCompleted,
        CreatedAt = s.CreatedAt,
        BsDate = NepaliDateService.AdToBs(s.Date)
    };
}
