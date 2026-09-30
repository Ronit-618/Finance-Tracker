using Microsoft.EntityFrameworkCore;
using FinanceTracker.Api.Models;

namespace FinanceTracker.Api.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<Entry> Entries => Set<Entry>();
    public DbSet<Bill> Bills => Set<Bill>();
    public DbSet<Transaction> Transactions => Set<Transaction>();
    public DbSet<Saving> Savings => Set<Saving>();
    public DbSet<Loan> Loans => Set<Loan>();
    public DbSet<LoanRepayment> LoanRepayments => Set<LoanRepayment>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Entry>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.SN).IsRequired();
            entity.Property(e => e.Date).IsRequired();
            entity.Property(e => e.Description).HasMaxLength(500);
            entity.Property(e => e.Category).HasConversion<string>().HasMaxLength(50);
            entity.Property(e => e.Type).HasConversion<string>().HasMaxLength(20);
            entity.Property(e => e.PaymentType).HasConversion<string>().HasMaxLength(20);
            entity.Property(e => e.Amount).HasColumnType("decimal(18,2)");
            entity.Property(e => e.ScreenshotPath).HasMaxLength(500);
            entity.Property(e => e.IsCompleted).HasDefaultValue(0);
            entity.HasIndex(e => e.SN);
            entity.HasIndex(e => e.Date);
        });

        modelBuilder.Entity<Bill>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.SN).IsRequired();
            entity.Property(e => e.Date).IsRequired();
            entity.Property(e => e.Description).HasMaxLength(500);
            entity.Property(e => e.Credit).HasColumnType("decimal(18,2)");
            entity.Property(e => e.Debit).HasColumnType("decimal(18,2)");
            entity.Property(e => e.Total).HasColumnType("decimal(18,2)");
            entity.HasOne(e => e.Entry)
                  .WithOne()
                  .HasForeignKey<Bill>(e => e.EntryId);
            entity.HasIndex(e => e.SN);
            entity.HasIndex(e => e.Date);
        });

        modelBuilder.Entity<Transaction>(entity =>
        {
            entity.HasKey(e => e.BillId);
            entity.Property(e => e.Income).HasColumnType("decimal(18,2)");
            entity.Property(e => e.Expense).HasColumnType("decimal(18,2)");
            entity.HasOne(e => e.Bill)
                  .WithOne()
                  .HasForeignKey<Transaction>(e => e.BillId);
        });

        modelBuilder.Entity<Saving>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.SN).IsRequired();
            entity.Property(e => e.Date).IsRequired();
            entity.Property(e => e.Description).HasMaxLength(500);
            entity.Property(e => e.Amount).HasColumnType("decimal(18,2)");
            entity.Property(e => e.Category).HasConversion<string>().HasMaxLength(20);
            entity.Property(e => e.ScreenshotPath).HasMaxLength(1000);
            entity.Property(e => e.IsCompleted).HasDefaultValue(0);
            entity.HasIndex(e => e.SN);
            entity.HasIndex(e => e.Date);
        });

        modelBuilder.Entity<Loan>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.SN).IsRequired();
            entity.Property(e => e.Date).IsRequired();
            entity.Property(e => e.Description).HasMaxLength(500);
            entity.Property(e => e.Amount).HasColumnType("decimal(18,2)");
            entity.Property(e => e.FromPerson).HasMaxLength(200);
            entity.Property(e => e.ToPerson).HasMaxLength(200);
            entity.Property(e => e.Direction).HasConversion<string>().HasMaxLength(20);
            entity.Property(e => e.Category).HasConversion<string>().HasMaxLength(20);
            entity.Property(e => e.ScreenshotPath).HasMaxLength(1000);
            entity.Property(e => e.IsCompleted).HasDefaultValue(0);
            entity.HasIndex(e => e.SN);
            entity.HasIndex(e => e.Date);
            entity.HasIndex(e => new { e.Direction, e.IsSettled });
        });

        modelBuilder.Entity<LoanRepayment>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Amount).HasColumnType("decimal(18,2)");
            entity.Property(e => e.Note).HasMaxLength(500);
            entity.Property(e => e.ScreenshotPath).HasMaxLength(1000);
            entity.HasOne(e => e.Loan)
                  .WithMany(l => l.Repayments)
                  .HasForeignKey(e => e.LoanId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(e => e.LoanId);
            entity.HasIndex(e => e.Date);
        });
    }
}
