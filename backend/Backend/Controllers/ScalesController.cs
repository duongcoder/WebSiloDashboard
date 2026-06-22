using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Configuration;
using RestSharp;
using System.Text.Json;
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

        public ScalesController(ILogger<ScalesController> logger, IHubContext<SiloHub> hubContext, IConfiguration configuration)
        {
            _logger = logger;
            _hubContext = hubContext;
            
            // Tự động lấy giá trị từ key "DbPostmanUrl", nếu trống sẽ lấy IP cũ làm mặc định
            _dbUrl = configuration.GetValue<string>("DbPostmanUrl") ?? "http://14.232.245.56:8089";
        }

        // Hàm login để lấy access_token
        private async Task<string?> GetToken()
        {
            var loginClient = new RestClient(_dbUrl);
            var loginRequest = new RestRequest("/api/Login", Method.Post);
            loginRequest.AddHeader("Content-Type", "application/json");
            loginRequest.AddStringBody(JsonSerializer.Serialize(new
            {
                username = "admin",
                password = "123"
            }), DataFormat.Json);

            var loginResponse = await loginClient.ExecuteAsync(loginRequest);
            if (!loginResponse.IsSuccessful || string.IsNullOrEmpty(loginResponse.Content))
            {
                _logger.LogError("Login failed: {msg}", loginResponse.Content);
                return null;
            }

            var loginJson = JsonDocument.Parse(loginResponse.Content!);
            return loginJson.RootElement.GetProperty("access_token").GetString();
        }

        // Endpoint: GET api/Scales/GetListScales
        [HttpGet("GetListScales")]
        public async Task<IActionResult> GetListScales()
        {
            var token = await GetToken();
            if (string.IsNullOrEmpty(token))
                return BadRequest("access_token not found");

            var scaleClient = new RestClient(_dbUrl);
            var scaleRequest = new RestRequest("/api/Scales/GetListScales", Method.Get);
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
                return BadRequest("access_token not found");

            var scaleClient = new RestClient(_dbUrl);
            var scaleRequest = new RestRequest($"/api/Scales/GetScaleValue?Id={id}", Method.Post);
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
                return BadRequest("access_token not found");

            var scaleClient = new RestClient(_dbUrl);
            var historyRequest = new RestRequest($"/api/Scales/GetHistory?sync={sync}&Id={id}", Method.Get);
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
