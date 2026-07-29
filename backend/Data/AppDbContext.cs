using Microsoft.EntityFrameworkCore;
using FinanceTracker.Api.Models;

namespace FinanceTracker.Api.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<Entry> Entries => Set<Entry>();
    public DbSet<Bill> Bills => Set<Bill>();
    public DbSet<Transaction> Transactions => Set<Transaction>();

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
    }
}
