using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Backend.Data;
using Backend.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using Microsoft.EntityFrameworkCore;

namespace SiloDashboardProxy.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private readonly IConfiguration _configuration;
        private readonly SiloDbContext _db;

        public AuthController(IConfiguration configuration, SiloDbContext db)
        {
            _configuration = configuration;
            _db = db;
        }

        [HttpPost("Login")]
        public IActionResult Login([FromBody] LoginRequest request)
        {
            // Lấy thông tin cấu hình từ appsettings.json của bạn
            var configUsername = _configuration["DbLogin:Username"];
            var configPassword = _configuration["DbLogin:Password"];

            var user = _db.Users.AsNoTracking().FirstOrDefault(u =>
                u.Username == request.Username ||
                (request.Username == configUsername && request.Password == configPassword && u.Username == configUsername));

            if (user != null &&
                (VerifyPassword(request.Password, user.PasswordHash) ||
                 (request.Username == configUsername && request.Password == configPassword)))
            {
                var jwtKey = _configuration["Jwt:Key"] ?? "silo_dashboard_dev_key_2026_change_me";
                var jwtIssuer = _configuration["Jwt:Issuer"];
                var jwtAudience = _configuration["Jwt:Audience"];

                var claims = new List<Claim>
                {
                    new(ClaimTypes.NameIdentifier, user.Id.ToString()),
                    new("sub", user.Id.ToString()),
                    new("userId", user.Id.ToString()),
                    new(ClaimTypes.Role, user.Role),
                    new(ClaimTypes.Name, user.Name),
                    new("avatarUrl", user.AvatarUrl ?? string.Empty),
                    new("username", user.Username)
                };

                var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey));
                var credentials = new SigningCredentials(signingKey, SecurityAlgorithms.HmacSha256);
                var expires = DateTime.UtcNow.AddHours(8);

                var token = new JwtSecurityToken(
                    issuer: string.IsNullOrWhiteSpace(jwtIssuer) ? null : jwtIssuer,
                    audience: string.IsNullOrWhiteSpace(jwtAudience) ? null : jwtAudience,
                    claims: claims,
                    notBefore: DateTime.UtcNow,
                    expires: expires,
                    signingCredentials: credentials);

                return Ok(new LoginResponse
                {
                    Success = true,
                    Token = new JwtSecurityTokenHandler().WriteToken(token),
                    Message = "Đăng nhập thành công!"
                });
            }

            return BadRequest(new LoginResponse 
            { 
                Success = false, 
                Message = "Tài khoản hoặc mật khẩu không chính xác!" 
            });
        }

        private static bool VerifyPassword(string password, string passwordHash)
        {
            if (string.IsNullOrWhiteSpace(passwordHash)) return false;

            var bytes = Encoding.UTF8.GetBytes(password);
            var hash = SHA256.HashData(bytes);
            return string.Equals(Convert.ToHexString(hash), passwordHash, StringComparison.OrdinalIgnoreCase);
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

