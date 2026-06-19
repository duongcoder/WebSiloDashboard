using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;
using RestSharp;
using System.Text.Json;

namespace Backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class SchedulersController : ControllerBase
    {
        private readonly ILogger<SchedulersController> _logger;
        private readonly string _dbUrl;

        public SchedulersController(ILogger<SchedulersController> logger, IConfiguration configuration)
        {
            _logger = logger;
            // Tự động lấy giá trị từ key "DbPostmanUrl", nếu trống sẽ lấy IP cũ làm mặc định
            _dbUrl = configuration.GetValue<string>("DbPostmanUrl") ?? "http://14.232.245.56:8089";
        }

        // Hàm login để lấy access_token (giống ScalesController)
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

        // Endpoint: GET api/Schedulers/GetSchedulers
        [HttpGet("GetSchedulers")]
        public async Task<IActionResult> GetSchedulers()
        {
            var token = await GetToken();
            if (string.IsNullOrEmpty(token))
                return BadRequest("access_token not found");

            var client = new RestClient(_dbUrl);
            var request = new RestRequest("/api/AccessControl/GetScheduler", Method.Get);
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
