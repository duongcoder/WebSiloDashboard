using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Configuration;
using RestSharp;
using System.Text.Json;
using System.Threading;
using Backend.Hubs;

namespace Backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ScalesController : ControllerBase
    {
        private readonly ILogger<ScalesController> _logger;
        private readonly IHubContext<SiloHub> _hubContext;
        private readonly string _dbUrl;
        private readonly string _dbUser;
        private readonly string _dbPassword;
        private static readonly SemaphoreSlim TokenLock = new(1, 1);
        private static string? _cachedToken;
        private static DateTime _cachedTokenExpiresUtc = DateTime.MinValue;

        public ScalesController(ILogger<ScalesController> logger, IHubContext<SiloHub> hubContext, IConfiguration configuration)
        {
            _logger = logger;
            _hubContext = hubContext;
            
            // Tự động lấy giá trị từ key "DbPostmanUrl", nếu trống sẽ lấy IP cũ làm mặc định
            _dbUrl = configuration.GetValue<string>("DbPostmanUrl") ?? "http://14.232.245.56:8089";
            _dbUser = configuration.GetValue<string>("DbLogin:Username") ?? "admin";
            _dbPassword = configuration.GetValue<string>("DbLogin:Password") ?? "123";
        }

        // Hàm login để lấy access_token
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

        // Endpoint: GET api/Scales/GetListScales
        [HttpGet("GetListScales")]
        public async Task<IActionResult> GetListScales()
        {
            var token = await GetToken();
            if (string.IsNullOrEmpty(token))
                return StatusCode(502, "Upstream login failed: access_token not found");

            var scaleClient = new RestClient(_dbUrl);
            var scaleRequest = new RestRequest("/api/Scales/GetListScales", Method.Get)
            {
                Timeout = 12000
            };
            scaleRequest.AddHeader("Authorization", $"Bearer {token}");

            var scaleResponse = await scaleClient.ExecuteAsync(scaleRequest);
            if (!scaleResponse.IsSuccessful)
            {
                _logger.LogError("GetListScales failed: {msg}", scaleResponse.Content);
                return StatusCode((int)scaleResponse.StatusCode, scaleResponse.Content);
            }

            return Content(scaleResponse.Content!, "application/json");
        }

        // Endpoint: GET api/Scales/GetScaleValue?id=1
        [HttpGet("GetScaleValue")]
        public async Task<IActionResult> GetScaleValue(int id)
        {
            var token = await GetToken();
            if (string.IsNullOrEmpty(token))
                return StatusCode(502, "Upstream login failed: access_token not found");

            var scaleClient = new RestClient(_dbUrl);
            var scaleRequest = new RestRequest($"/api/Scales/GetScaleValue?Id={id}", Method.Post)
            {
                Timeout = 12000
            };
            scaleRequest.AddHeader("Authorization", $"Bearer {token}");

            var scaleResponse = await scaleClient.ExecuteAsync(scaleRequest);
            if (!scaleResponse.IsSuccessful)
            {
                _logger.LogError("GetScaleValue failed: {msg}", scaleResponse.Content);
                return StatusCode((int)scaleResponse.StatusCode, scaleResponse.Content);
            }

            // Parse JSON trước khi gửi qua Hub
            // var jsonDoc = JsonDocument.Parse(scaleResponse.Content!);
            // var scaleValue = jsonDoc.RootElement.GetProperty("value").GetDouble();

            // await _hubContext.Clients.All.SendAsync("ReceiveScaleValue", new Dictionary<string, object>
            // {
            //     { "value", scaleValue }
            // });

            // _logger.LogInformation("Scale value {val} sent to Hub", scaleValue);

            return Content(scaleResponse.Content!, "application/json");
        }

        // Endpoint: GET api/Scales/GetHistory?sync=-1&Id=-1
        // Proxy qua backend để tránh lỗi CORS khi Flutter Web gọi trực tiếp dịch vụ ngoài.
        [HttpGet("GetHistory")]
        public async Task<IActionResult> GetHistory(int sync = -1, int id = -1)
        {
            var token = await GetToken();
            if (string.IsNullOrEmpty(token))
                return StatusCode(502, "Upstream login failed: access_token not found");

            var scaleClient = new RestClient(_dbUrl);
            var historyRequest = new RestRequest($"/api/Scales/GetHistory?sync={sync}&Id={id}", Method.Get)
            {
                Timeout = 12000
            };
            historyRequest.AddHeader("Authorization", $"Bearer {token}");

            var historyResponse = await scaleClient.ExecuteAsync(historyRequest);
            if (!historyResponse.IsSuccessful)
            {
                _logger.LogError("GetHistory failed: {msg}", historyResponse.Content);
                return StatusCode((int)historyResponse.StatusCode, historyResponse.Content);
            }

            return Content(historyResponse.Content!, "application/json");
        }
    }
}
