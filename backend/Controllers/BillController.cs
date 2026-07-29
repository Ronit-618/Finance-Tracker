using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using FinanceTracker.Api.Data;
using FinanceTracker.Api.Dtos;
using FinanceTracker.Api.Models;

namespace FinanceTracker.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class BillController : ControllerBase
{
    private readonly AppDbContext _db;

    public BillController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<List<BillResponse>>> GetAll()
    {
        var bills = await _db.Bills
            .OrderBy(b => b.SN)
            .ToListAsync();

        var responses = new List<BillResponse>();
        decimal runningBalance = 0;

        foreach (var bill in bills)
        {
            runningBalance += bill.Credit - bill.Debit;
            responses.Add(MapToResponse(bill, runningBalance));
        }

        return responses;
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<BillResponse>> GetById(int id)
    {
        var bill = await _db.Bills.FindAsync(id);
        if (bill is null) return NotFound();

        var balance = await _db.Bills
            .Where(b => b.SN <= bill.SN)
            .SumAsync(b => b.Credit - b.Debit);

        return MapToResponse(bill, balance);
    }

    private static BillResponse MapToResponse(Bill b, decimal balance) => new()
    {
        Id = b.Id,
        SN = b.SN,
        Date = b.Date,
        Description = b.Description,
        Credit = b.Credit,
        Debit = b.Debit,
        Total = b.Total,
        Balance = balance,
        CreatedAt = b.CreatedAt
    };
}
