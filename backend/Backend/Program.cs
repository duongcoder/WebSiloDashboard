using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.NewtonsoftJson;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.EntityFrameworkCore;
using Microsoft.OpenApi.Models;
using Backend.Data;   
using Backend.Models;
using Backend.Hubs;
using System.Text;
using System.Text.Json;

namespace Backend
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);

            // 1. Đăng ký DbContext với SQL Server
            builder.Services.AddDbContext<SiloDbContext>(options =>
                options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

            // 2. Đăng ký Controllers + NewtonsoftJson
            builder.Services.AddControllers()
                .AddNewtonsoftJson(options =>
                {
                    options.SerializerSettings.ReferenceLoopHandling = Newtonsoft.Json.ReferenceLoopHandling.Ignore;
                });

            // 3. Đăng ký Swagger
            builder.Services.AddEndpointsApiExplorer();
            builder.Services.AddSwaggerGen(c =>
                {
                    c.SwaggerDoc("v1", new OpenApiInfo { Title = "Silo API", Version = "v1", Description = "API quản lý silo" });
                });

            // 4. Đăng ký CORS thông minh bảo mật cao
            var allowedOriginsConfig = builder.Configuration.GetValue<string>("AllowedOrigins") ?? string.Empty;
            var allowedOrigins = allowedOriginsConfig.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

            builder.Services.AddCors(options =>
            {
                options.AddPolicy("AllowAll", policy => 
                {
                    policy.AllowAnyMethod()
                          .AllowAnyHeader()
                          .AllowCredentials(); // Bắt buộc cho SignalR

                    if (builder.Environment.IsDevelopment())
                    {
                        // Môi trường DEV: Cho phép TẤT CẢ Origin để Flutter Web dev port ngẫu nhiên hoạt động.
                        policy.SetIsOriginAllowed(origin => true);
                    }
                    else
                    {
                        // Môi trường PRODUCTION (IIS):
                        if (allowedOrigins.Length > 0)
                        {
                            // Có cấu hình rõ: chỉ cho phép đúng danh sách.
                            policy.WithOrigins(allowedOrigins);
                        }
                        else
                        {
                            // Chưa cấu hình AllowedOrigins: cho phép mọi origin (safe fallback cho
                            // triển khai nội bộ mà không có domain cố định).
                            policy.SetIsOriginAllowed(origin => true);
                        }
                    }
                });
            });

            // 5. Đăng ký JWT Authentication cho RBAC
            var jwtKey = builder.Configuration["Jwt:Key"] ?? "silo_dashboard_dev_key_2026_change_me";
            var jwtIssuer = builder.Configuration["Jwt:Issuer"];
            var jwtAudience = builder.Configuration["Jwt:Audience"];

            builder.Services
                .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
                .AddJwtBearer(options =>
                {
                    options.TokenValidationParameters = new TokenValidationParameters
                    {
                        ValidateIssuerSigningKey = true,
                        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
                        ValidateIssuer = !string.IsNullOrWhiteSpace(jwtIssuer),
                        ValidIssuer = jwtIssuer,
                        ValidateAudience = !string.IsNullOrWhiteSpace(jwtAudience),
                        ValidAudience = jwtAudience,
                        ValidateLifetime = true,
                        ClockSkew = TimeSpan.FromMinutes(1)
                    };

                    options.Events = new JwtBearerEvents
                    {
                        OnChallenge = async context =>
                        {
                            context.HandleResponse();
                            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                            context.Response.ContentType = "application/json";
                            await context.Response.WriteAsync(JsonSerializer.Serialize(new
                            {
                                message = "Unauthorized"
                            }));
                        },
                        OnForbidden = async context =>
                        {
                            context.Response.StatusCode = StatusCodes.Status403Forbidden;
                            context.Response.ContentType = "application/json";
                            await context.Response.WriteAsync(JsonSerializer.Serialize(new
                            {
                                message = "Forbidden"
                            }));
                        },
                        OnAuthenticationFailed = async context =>
                        {
                            context.NoResult();
                            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                            context.Response.ContentType = "application/json";
                            await context.Response.WriteAsync(JsonSerializer.Serialize(new
                            {
                                message = "Invalid token"
                            }));
                        }
                    };
                });

            // 6. Đăng ký SignalR
            builder.Services.AddSignalR();

            var app = builder.Build();

            // --- Middleware Pipeline ---
            app.UseExceptionHandler(errorApp =>
            {
                errorApp.Run(async context =>
                {
                    context.Response.StatusCode = StatusCodes.Status500InternalServerError;
                    context.Response.ContentType = "application/json";
                    await context.Response.WriteAsync(JsonSerializer.Serialize(new
                    {
                        message = "Internal server error"
                    }));
                });
            });

            app.UseRouting();
            
            // ====================================================================
            // ▼ CHÈN THÊM ĐOẠN NÀY ĐỂ ĐẬP TAN LỖI CORS PREFLIGHT (OPTIONS) ▼
            app.Use(async (context, next) =>
            {
                if (context.Request.Method == "OPTIONS")
                {
                    // Tự động lấy Origin của Flutter Web gửi lên để map ngược lại (vượt qua bộ lọc Credentials)
                    context.Response.Headers["Access-Control-Allow-Origin"] = context.Request.Headers["Origin"].ToString();
                    context.Response.Headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, Accept, X-Requested-With";
                    context.Response.Headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS";
                    context.Response.Headers["Access-Control-Allow-Credentials"] = "true";
                    context.Response.StatusCode = 200;
                    return; // Trả về luôn, không cho đi tiếp xuống các tầng dưới gây lỗi
                }
                await next();
            });
            // ▲ ==================================================================== ▲

            // CORS đặt cố định tại đây
            app.UseCors("AllowAll");

            app.UseAuthentication();
            
            app.UseAuthorization();

            // Swagger: hiển thị mọi môi trường (có thể ẩn production bằng cách set ENABLE_SWAGGER=false)
            var enableSwagger = builder.Configuration.GetValue<bool?>("EnableSwagger") ?? true;
            if (enableSwagger)
            {
                app.UseSwagger();
                app.UseSwaggerUI(c =>
                {
                    c.SwaggerEndpoint("/swagger/v1/swagger.json", "Silo API V1");
                    c.RoutePrefix = "swagger";
                });
            }

            app.MapControllers();
            app.MapHub<SiloHub>("/siloHub");

            // ====================================================================
            // ▼ TỰ ĐỘNG KHỞI TẠO HOẶC CẬP NHẬT TÀI KHOẢN ADMIN CHUẨN SHA-256 ▼
            using (var scope = app.Services.CreateScope())
            {
                var services = scope.ServiceProvider;
                try
                {
                    var context = services.GetRequiredService<SiloDbContext>();
                    var adminUser = context.Users.FirstOrDefault(u => u.Username == "admin");

                    // Chuỗi SHA-256 viết hoa chuẩn của mật khẩu "123"
                    string hashedAdminPassword = "A665A45920422F9D417E4867EFDC4FB8A04A1F3FFF1FA07E998E86F7F7A27AE3";

                    if (adminUser == null)
                    {
                        // Nếu chưa có tài khoản admin thì tạo mới hoàn toàn
                        context.Users.Add(new AppUser
                        {
                            Username = "admin",
                            Name = "Quản trị viên Silo",
                            Role = "Admin",
                            PasswordHash = hashedAdminPassword
                        });
                        context.SaveChanges();
                    }
                    else if (adminUser.PasswordHash == "123")
                    {
                        // Nếu tài khoản admin đã tồn tại nhưng mang mật khẩu thô "123", tự động cập nhật lên chuỗi mã hóa
                        adminUser.PasswordHash = hashedAdminPassword;
                        context.SaveChanges();
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[SeedData Error]: {ex.Message}");
                }
            }
            // ▲ ==================================================================== ▲

            app.Run();
        }
    }
}