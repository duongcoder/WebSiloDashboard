using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.NewtonsoftJson;
using Microsoft.EntityFrameworkCore;
using Microsoft.OpenApi.Models;
using Backend.Data;   
using Backend.Models;
using Backend.Hubs;

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
                        // Môi trường DEV: Cho phép TẤT CẢ các Origin/Cổng ngẫu nhiên từ Flutter Web
                        // Hàm này biến đổi Origin động để vượt qua ràng buộc khắt khe của AllowCredentials()
                        policy.SetIsOriginAllowed(origin => true);
                    }
                    else
                    {
                        // Môi trường KHÁCH HÀNG (Production): Ép buộc bảo mật đúng danh sách cấu hình
                        if (allowedOrigins.Length > 0)
                        {
                            policy.WithOrigins(allowedOrigins);
                        }
                    }
                });
            });

            // 5. Đăng ký SignalR
            builder.Services.AddSignalR();

            var app = builder.Build();

            // --- Middleware Pipeline ---
            if (app.Environment.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }

            app.UseRouting();
            
            // CORS đặt cố định tại đây
            app.UseCors("AllowAll");
            
            app.UseAuthorization();

            // Cấu hình Swagger UI trang gốc
            app.UseSwagger();
            app.UseSwaggerUI(c =>
            {
                c.SwaggerEndpoint("/swagger/v1/swagger.json", "Silo API V1");
                c.RoutePrefix = string.Empty; 
            });

            app.MapControllers();
            app.MapHub<SiloHub>("/siloHub");

            app.Run();
        }
    }
}