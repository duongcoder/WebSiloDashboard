using System.Data;
using System.Data.SqlClient;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);

// Config: lấy từ env để bạn không phải commit password
var port = builder.Configuration["PORT"] ?? "5005";
var sqlConnectionString = builder.Configuration["SQL_CONNECTION_STRING"] ??
    Environment.GetEnvironmentVariable("SQL_CONNECTION_STRING") ?? "";

if (string.IsNullOrWhiteSpace(sqlConnectionString))
{
    Console.WriteLine("Missing SQL_CONNECTION_STRING env.");
}

builder.WebHost.UseUrls($"http://localhost:{port}");

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy
            .AllowAnyOrigin()
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

var app = builder.Build();

// CORS middleware
app.UseCors();


app.MapGet("/health", () => Results.Ok(new { ok = true }));

app.MapGet("/silos", async () =>
{
    // Nếu chưa cấu hình connection string, trả rỗng để không làm crash frontend
    if (string.IsNullOrWhiteSpace(sqlConnectionString))
    {
        return Results.Ok(new List<object>());
    }

    // Code-first LINQ (dạng mapping trong memory):
    // - Với SqlClient thuần thì không thể LINQ-to-SQL server-side
    // - Tuy nhiên ta dùng LINQ để transform dữ liệu sang dictionary
    const string sql = @"
        SELECT 
            id,
            weight,
            level,
            indicatorId,
            indicatorPort,
            indicatorMaxLoad,
            controllerIp,
            controllerPort,
            controllerSn
        FROM silos
    ";

    var resultRows = new List<Dictionary<string, object?>>();

    await using var conn = new SqlConnection(sqlConnectionString);
    await conn.OpenAsync();

    await using var cmd = new SqlCommand(sql, conn);
    await using var reader = await cmd.ExecuteReaderAsync(CommandBehavior.CloseConnection);

    while (await reader.ReadAsync())
    {
        object? Get(string name)
        {
            var ordinal = reader.GetOrdinal(name);
            return reader.IsDBNull(ordinal) ? null : reader.GetValue(ordinal);
        }

        resultRows.Add(new Dictionary<string, object?>
        {
            ["id"] = Get("id"),
            ["weight"] = Get("weight"),
            ["level"] = Get("level"),
            ["indicatorId"] = Get("indicatorId"),
            ["indicatorPort"] = Get("indicatorPort"),
            ["indicatorMaxLoad"] = Get("indicatorMaxLoad"),
            ["controllerIp"] = Get("controllerIp"),
            ["controllerPort"] = Get("controllerPort"),
            ["controllerSn"] = Get("controllerSn"),
        });
    }

    // LINQ: normalize key set (giúp ổn định payload cho Flutter)
    var normalized = resultRows
        .Select(r => new Dictionary<string, object?>
        {
            ["id"] = r.ContainsKey("id") ? r["id"] : null,
            ["weight"] = r.ContainsKey("weight") ? r["weight"] : null,
            ["level"] = r.ContainsKey("level") ? r["level"] : null,
            ["indicatorId"] = r.ContainsKey("indicatorId") ? r["indicatorId"] : null,
            ["indicatorPort"] = r.ContainsKey("indicatorPort") ? r["indicatorPort"] : null,
            ["indicatorMaxLoad"] = r.ContainsKey("indicatorMaxLoad") ? r["indicatorMaxLoad"] : null,
            ["controllerIp"] = r.ContainsKey("controllerIp") ? r["controllerIp"] : null,
            ["controllerPort"] = r.ContainsKey("controllerPort") ? r["controllerPort"] : null,
            ["controllerSn"] = r.ContainsKey("controllerSn") ? r["controllerSn"] : null,
        })
        .ToList();

    return Results.Ok(normalized);
});

app.Run();

