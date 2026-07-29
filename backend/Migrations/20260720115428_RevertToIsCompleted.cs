using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace FinanceTracker.Api.Migrations
{
    /// <inheritdoc />
    public partial class RevertToIsCompleted : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Entries_EntryStatuses_EntryStatusId",
                table: "Entries");

            migrationBuilder.DropTable(
                name: "EntryStatuses");

            migrationBuilder.DropIndex(
                name: "IX_Entries_EntryStatusId",
                table: "Entries");

            migrationBuilder.DropColumn(
                name: "EntryStatusId",
                table: "Entries");

            migrationBuilder.AddColumn<int>(
                name: "IsCompleted",
                table: "Entries",
                type: "int",
                nullable: false,
                defaultValue: 0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IsCompleted",
                table: "Entries");

            migrationBuilder.AddColumn<int>(
                name: "EntryStatusId",
                table: "Entries",
                type: "int",
                nullable: false,
                defaultValue: 1);

            migrationBuilder.CreateTable(
                name: "EntryStatuses",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_EntryStatuses", x => x.Id);
                });

            migrationBuilder.InsertData(
                table: "EntryStatuses",
                columns: new[] { "Id", "Name" },
                values: new object[,]
                {
                    { 1, "Pending" },
                    { 2, "Completed" },
                    { 3, "Edited" }
                });

            migrationBuilder.CreateIndex(
                name: "IX_Entries_EntryStatusId",
                table: "Entries",
                column: "EntryStatusId");

            migrationBuilder.AddForeignKey(
                name: "FK_Entries_EntryStatuses_EntryStatusId",
                table: "Entries",
                column: "EntryStatusId",
                principalTable: "EntryStatuses",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
