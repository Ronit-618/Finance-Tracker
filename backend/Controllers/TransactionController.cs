using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using FinanceTracker.Api.Data;
using FinanceTracker.Api.Dtos;

namespace FinanceTracker.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class TransactionController : ControllerBase
{
    private readonly AppDbContext _db;

    public TransactionController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<List<TransactionResponse>>> GetAll()
    {
        var transactions = await _db.Transactions
            .OrderBy(t => t.BillId)
            .ToListAsync();

        return transactions.Select(t => new TransactionResponse
        {
            BillId = t.BillId,
            Income = t.Income,
            Expense = t.Expense
        }).ToList();
    }

    [HttpGet("{billId:int}")]
    public async Task<ActionResult<TransactionResponse>> GetByBillId(int billId)
    {
        var t = await _db.Transactions.FindAsync(billId);
        if (t is null) return NotFound();

        return new TransactionResponse
        {
            BillId = t.BillId,
            Income = t.Income,
            Expense = t.Expense
        };
    }
}
