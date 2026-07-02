using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Backend.Migrations
{
    /// <inheritdoc />
    public partial class UpdateAppUser : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // migrationBuilder.CreateTable(
            //     name: "ColData",
            //     columns: table => new
            //     {
            //         Id = table.Column<int>(type: "int", nullable: false)
            //             .Annotation("SqlServer:Identity", "1, 1"),
            //         SiloId = table.Column<string>(type: "nvarchar(max)", nullable: false),
            //         RecordDate = table.Column<DateTime>(type: "datetime2", nullable: false),
            //         WeightKg = table.Column<double>(type: "float", nullable: false)
            //     },
            //     constraints: table =>
            //     {
            //         table.PrimaryKey("PK_ColData", x => x.Id);
            //     });

            // migrationBuilder.CreateTable(
            //     name: "Controllers",
            //     columns: table => new
            //     {
            //         ControllerId = table.Column<string>(type: "nvarchar(100)", nullable: false),
            //         Ip = table.Column<string>(type: "nvarchar(max)", nullable: false),
            //         Port = table.Column<int>(type: "int", nullable: false),
            //         SerialNumber = table.Column<string>(type: "nvarchar(100)", nullable: false)
            //     },
            //     constraints: table =>
            //     {
            //         table.PrimaryKey("PK_Controllers", x => x.ControllerId);
            //     });

            // migrationBuilder.CreateTable(
            //     name: "Indicators",
            //     columns: table => new
            //     {
            //         IndicatorId = table.Column<string>(type: "nvarchar(450)", nullable: false),
            //         Name = table.Column<string>(type: "nvarchar(max)", nullable: false),
            //         Port = table.Column<string>(type: "nvarchar(max)", nullable: false),
            //         BaudRate = table.Column<int>(type: "int", nullable: false)
            //     },
            //     constraints: table =>
            //     {
            //         table.PrimaryKey("PK_Indicators", x => x.IndicatorId);
            //     });

            // migrationBuilder.CreateTable(
            //     name: "Silos",
            //     columns: table => new
            //     {
            //         Id = table.Column<string>(type: "nvarchar(50)", nullable: false),
            //         Weight = table.Column<double>(type: "float", nullable: false),
            //         Level = table.Column<double>(type: "float", nullable: false)
            //     },
            //     constraints: table =>
            //     {
            //         table.PrimaryKey("PK_Silos", x => x.Id);
            //     });

            migrationBuilder.CreateTable(
                name: "Users",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Username = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    PasswordHash = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false),
                    AvatarUrl = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    Role = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Users", x => x.Id);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // migrationBuilder.DropTable(
            //     name: "ColData");

            // migrationBuilder.DropTable(
            //     name: "Controllers");

            // migrationBuilder.DropTable(
            //     name: "Indicators");

            // migrationBuilder.DropTable(
            //     name: "Silos");

            migrationBuilder.DropTable(
                name: "Users");
        }
    }
}
