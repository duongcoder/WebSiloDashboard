using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;
using RestSharp;
using System.Text.Json;
using System.Threading;

namespace Backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class SchedulersController : ControllerBase
    {
        private readonly ILogger<SchedulersController> _logger;
        private readonly string _dbUrl;
        private readonly string _dbUser;
        private readonly string _dbPassword;
        private static readonly SemaphoreSlim TokenLock = new(1, 1);
        private static string? _cachedToken;
        private static DateTime _cachedTokenExpiresUtc = DateTime.MinValue;

        public SchedulersController(ILogger<SchedulersController> logger, IConfiguration configuration)
        {
            _logger = logger;
            // Tự động lấy giá trị từ key "DbPostmanUrl", nếu trống sẽ lấy IP cũ làm mặc định
            _dbUrl = configuration.GetValue<string>("DbPostmanUrl") ?? "http://14.232.245.56:8089";
            _dbUser = configuration.GetValue<string>("DbLogin:Username") ?? "admin";
            _dbPassword = configuration.GetValue<string>("DbLogin:Password") ?? "123";
        }

        // Hàm login để lấy access_token (giống ScalesController)
        private async Task<string?> GetToken()
        {
            if (!string.IsNullOrWhiteSpace(_cachedToken) && _cachedTokenExpiresUtc > DateTime.UtcNow)
            {
                return _cachedToken;
            }

            await TokenLock.WaitAsync();
            try
            {
                if (!string.IsNullOrWhiteSpace(_cachedToken) && _cachedTokenExpiresUtc > DateTime.UtcNow)
                {
                    return _cachedToken;
                }

                var loginClient = new RestClient(_dbUrl);
                var loginRequest = new RestRequest("/api/Login", Method.Post)
                {
                    Timeout = 10000
                };
                loginRequest.AddHeader("Content-Type", "application/json");
                loginRequest.AddStringBody(JsonSerializer.Serialize(new
                {
                    username = _dbUser,
                    password = _dbPassword
                }), DataFormat.Json);

                var loginResponse = await loginClient.ExecuteAsync(loginRequest);
                if (!loginResponse.IsSuccessful || string.IsNullOrEmpty(loginResponse.Content))
                {
                    _logger.LogError(
                        "Login failed. Status: {status}, Error: {error}, Content: {content}",
                        loginResponse.StatusCode,
                        loginResponse.ErrorMessage,
                        loginResponse.Content ?? "(null)");
                    return null;
                }

                var loginJson = JsonDocument.Parse(loginResponse.Content!);
                if (!loginJson.RootElement.TryGetProperty("access_token", out var tokenElement))
                {
                    _logger.LogError("Login succeeded but access_token missing. Payload: {payload}", loginResponse.Content);
                    return null;
                }

                var token = tokenElement.GetString();
                if (string.IsNullOrWhiteSpace(token))
                {
                    _logger.LogError("Login returned empty access_token. Payload: {payload}", loginResponse.Content);
                    return null;
                }

                _cachedToken = token;
                _cachedTokenExpiresUtc = DateTime.UtcNow.AddMinutes(10);
                return token;
            }
            finally
            {
                TokenLock.Release();
            }
        }

        // Endpoint: GET api/Schedulers/GetSchedulers
        [HttpGet("GetSchedulers")]
        public async Task<IActionResult> GetSchedulers()
        {
            var token = await GetToken();
            if (string.IsNullOrEmpty(token))
                return StatusCode(502, "Upstream login failed: access_token not found");

            var client = new RestClient(_dbUrl);
            var request = new RestRequest("/api/AccessControl/GetScheduler", Method.Get)
            {
                Timeout = 12000
            };
            request.AddHeader("Authorization", $"Bearer {token}");

            var response = await client.ExecuteAsync(request);
            if (!response.IsSuccessful)
            {
                _logger.LogError("GetSchedulers failed: {msg}", response.Content);
                return StatusCode((int)response.StatusCode, response.Content);
            }

            return Content(response.Content!, "application/json");
        }
    }
}
