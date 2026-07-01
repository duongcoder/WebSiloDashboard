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

        // Logout: với hệ thống JWT "pure" (không refresh token)
        // thì server chỉ cần trả về trạng thái thành công.
        // Nếu bạn sau này thêm refresh token/blacklist thì logic có thể mở rộng ở đây.
        [HttpPost("Logout")]
        public IActionResult Logout()
        {
            // Xóa session nếu có bật Session middleware.
            HttpContext.Session?.Clear();

            // Xóa cookie phía server theo kiểu best-effort.
            foreach (var cookieKey in Request.Cookies.Keys)
            {
                Response.Cookies.Delete(cookieKey);
            }

            return Ok();
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

    public class AuthLogoutRequest
    {
        // Có thể bỏ nếu bạn không cần gửi token.
        // Để tương lai (blacklist/refresh token) thì giữ lại.
        public string? Token { get; set; }
    }

    public class AuthLogoutResponse
    {
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
    }
}

