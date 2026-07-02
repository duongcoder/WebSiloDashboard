using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.IdentityModel.Tokens.Jwt;
using Backend.Data;
using Backend.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Backend.Controllers
{
    [ApiController]
    [Route("api/v1/users")]
    [Authorize]
    public class UserController : ControllerBase
    {
        private readonly SiloDbContext _db;

        public UserController(SiloDbContext db)
        {
            _db = db;
        }

        [HttpGet]
        public async Task<IActionResult> GetUsers()
        {
            try
            {
                if (User.IsInRole("Admin"))
                {
                    var users = await _db.Users
                        .AsNoTracking()
                        .Where(u => u.Role != "Admin")
                        .Select(u => new
                        {
                            id = u.Id,
                            username = u.Username,
                            name = u.Name,
                            avatarUrl = u.AvatarUrl,
                            role = u.Role
                        })
                        .ToListAsync();

                    return Ok(users);
                }

                var userId = GetUserIdFromToken();
                if (!userId.HasValue || userId.Value <= 0)
                {
                    return Unauthorized(new { message = "Không xác định được người dùng từ token." });
                }

                var me = await _db.Users
                    .AsNoTracking()
                    .Where(u => u.Id == userId.Value)
                    .Select(u => new
                    {
                        id = u.Id,
                        username = u.Username,
                        name = u.Name,
                        avatarUrl = u.AvatarUrl,
                        role = u.Role
                    })
                    .FirstOrDefaultAsync();

                if (me == null)
                {
                    return NotFound(new { message = "Không tìm thấy tài khoản." });
                }

                return Ok(new[] { me });
            }
            catch (Exception ex)
            {
                return StatusCode(StatusCodes.Status500InternalServerError, new
                {
                    message = $"Lỗi hệ thống: {ex.Message}"
                });
            }
        }

        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> CreateUser([FromBody] CreateUserRequest request)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(request.Username) || string.IsNullOrWhiteSpace(request.Password))
                {
                    return BadRequest(new { message = "Username và Password là bắt buộc." });
                }

                var exists = await _db.Users.AnyAsync(u => u.Username == request.Username);
                if (exists)
                {
                    return Conflict(new { message = "Tên đăng nhập đã tồn tại." });
                }

                var user = new AppUser
                {
                    Username = request.Username.Trim(),
                    PasswordHash = ComputeSha256(request.Password),
                    Name = string.IsNullOrWhiteSpace(request.Name) ? request.Username.Trim() : request.Name.Trim(),
                    AvatarUrl = string.IsNullOrWhiteSpace(request.AvatarUrl) ? null : request.AvatarUrl.Trim(),
                    Role = string.IsNullOrWhiteSpace(request.Role) ? "User" : request.Role.Trim()
                };

                _db.Users.Add(user);
                await _db.SaveChangesAsync();

                return Ok(new
                {
                    id = user.Id,
                    username = user.Username,
                    name = user.Name,
                    avatarUrl = user.AvatarUrl,
                    role = user.Role
                });
            }
            catch (Exception ex)
            {
                return StatusCode(StatusCodes.Status500InternalServerError, new
                {
                    message = $"Lỗi hệ thống: {ex.Message}"
                });
            }
        }

        [HttpPut("{id:int}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> UpdateUser(int id, [FromBody] UpdateUserRequest request)
        {
            try
            {
                var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == id);
                if (user == null)
                {
                    return NotFound(new { message = "Không tìm thấy tài khoản." });
                }

                if (!string.IsNullOrWhiteSpace(request.Username))
                {
                    user.Username = request.Username.Trim();
                }

                if (!string.IsNullOrWhiteSpace(request.Password))
                {
                    user.PasswordHash = ComputeSha256(request.Password);
                }

                if (!string.IsNullOrWhiteSpace(request.Name))
                {
                    user.Name = request.Name.Trim();
                }

                if (request.AvatarUrl != null)
                {
                    user.AvatarUrl = string.IsNullOrWhiteSpace(request.AvatarUrl)
                        ? null
                        : request.AvatarUrl.Trim();
                }

                if (!string.IsNullOrWhiteSpace(request.Role))
                {
                    user.Role = request.Role.Trim();
                }

                await _db.SaveChangesAsync();

                return Ok(new
                {
                    id = user.Id,
                    username = user.Username,
                    name = user.Name,
                    avatarUrl = user.AvatarUrl,
                    role = user.Role
                });
            }
            catch (Exception ex)
            {
                return StatusCode(StatusCodes.Status500InternalServerError, new
                {
                    message = $"Lỗi hệ thống: {ex.Message}"
                });
            }
        }

        private int? GetUserIdFromToken()
        {
            var claimValue = User.FindFirstValue(ClaimTypes.NameIdentifier)
                            ?? User.FindFirstValue("sub")
                            ?? User.FindFirstValue("userId");

            if (int.TryParse(claimValue, out var claimUserId) && claimUserId > 0)
            {
                return claimUserId;
            }

            var authHeader = Request.Headers.Authorization.ToString();
            if (string.IsNullOrWhiteSpace(authHeader) || !authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            {
                return null;
            }

            var token = authHeader["Bearer ".Length..].Trim();
            if (string.IsNullOrWhiteSpace(token))
            {
                return null;
            }

            var handler = new JwtSecurityTokenHandler();
            if (!handler.CanReadToken(token))
            {
                return null;
            }

            var jwt = handler.ReadJwtToken(token);
            var tokenUserId = jwt.Claims.FirstOrDefault(c =>
                c.Type == ClaimTypes.NameIdentifier || c.Type == "sub" || c.Type == "userId")?.Value;

            if (int.TryParse(tokenUserId, out var parsed) && parsed > 0)
            {
                return parsed;
            }

            return null;
        }

        private static string ComputeSha256(string plainText)
        {
            var bytes = Encoding.UTF8.GetBytes(plainText);
            var hash = SHA256.HashData(bytes);
            return Convert.ToHexString(hash);
        }
    }

    public class CreateUserRequest
    {
        public string Username { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string? Name { get; set; }
        public string? AvatarUrl { get; set; }
        public string Role { get; set; } = "User";
    }

    public class UpdateUserRequest
    {
        public string? Username { get; set; }
        public string? Password { get; set; }
        public string? Name { get; set; }
        public string? AvatarUrl { get; set; }
        public string? Role { get; set; }
    }
}
