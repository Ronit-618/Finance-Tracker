using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FinanceTracker.Api.Migrations
{
    /// <inheritdoc />
    public partial class LinkBillToEntry : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "EntryId",
                table: "Bills",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateIndex(
                name: "IX_Bills_EntryId",
                table: "Bills",
                column: "EntryId",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Bills_Entries_EntryId",
                table: "Bills",
                column: "EntryId",
                principalTable: "Entries",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Bills_Entries_EntryId",
                table: "Bills");

            migrationBuilder.DropIndex(
                name: "IX_Bills_EntryId",
                table: "Bills");

            migrationBuilder.DropColumn(
                name: "EntryId",
                table: "Bills");
        }
    }
}
