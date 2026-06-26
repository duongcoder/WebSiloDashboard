using Microsoft.AspNetCore.Mvc;

namespace SiloDashboardProxy.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private readonly IConfiguration _configuration;

        public AuthController(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        [HttpPost("Login")]
        public IActionResult Login([FromBody] LoginRequest request)
        {
            // Lấy thông tin cấu hình từ appsettings.json của bạn
            var configUsername = _configuration["DbLogin:Username"];
            var configPassword = _configuration["DbLogin:Password"];

            if (request.Username == configUsername && request.Password == configPassword)
            {
                // Trả về token giả lập kèm trạng thái thành công
                return Ok(new LoginResponse
                {
                    Success = true,
                    Token = "silo_dashboard_secure_token_2026_xyz",
                    Message = "Đăng nhập thành công!"
                });
            }

            return BadRequest(new LoginResponse 
            { 
                Success = false, 
                Message = "Tài khoản hoặc mật khẩu không chính xác!" 
            });
        }
    }

    public class LoginRequest
    {
        public string Username { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
    }

    public class LoginResponse
    {
        public bool Success { get; set; }
        public string Token { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
    }
}