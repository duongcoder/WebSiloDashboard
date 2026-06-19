// using Microsoft.AspNetCore.Mvc;
// using Microsoft.AspNetCore.Mvc.NewtonsoftJson;
// using Microsoft.EntityFrameworkCore;
// using Microsoft.OpenApi.Models;
// using Backend.Data;   // nơi chứa SiloDbContext
// using Backend.Models;
// using Backend.Hubs;

// namespace Backend
// {
//     public class Program
//     {
//         public static void Main(string[] args)
//         {
//             var builder = WebApplication.CreateBuilder(args);

//             // Đăng ký DbContext với SQL Server
//             builder.Services.AddDbContext<SiloDbContext>(options =>
//                 options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

//             // Đăng ký Controllers
//             builder.Services.AddControllers()
//                 .AddNewtonsoftJson(options =>
//                 {
//                     options.SerializerSettings.ReferenceLoopHandling = Newtonsoft.Json.ReferenceLoopHandling.Ignore;
//                 });

//             // Đăng ký Swagger
//             builder.Services.AddEndpointsApiExplorer();
//             builder.Services.AddSwaggerGen(c =>
//             {
//                 c.SwaggerDoc("v1", new OpenApiInfo
//                 {
//                     Title = "Silo API",
//                     Version = "v1",
//                     Description = "API quản lý silo"
//                 });
//             });

//             // Đăng ký CORS
//             builder.Services.AddCors(options =>
//             {
//                 options.AddPolicy("AllowAll",
//                     policy => policy.AllowAnyOrigin()
//                                     .AllowAnyMethod()
//                                     .AllowAnyHeader());
//             });

//             builder.Services.AddSignalR();

//             var app = builder.Build();

//             // Middleware pipeline
//             // app.UseHttpsRedirection();
//             app.UseRouting();
//             app.UseCors("AllowAll");
//             app.UseAuthorization();

//             // Swagger middleware
//             app.UseSwagger();
//             app.UseSwaggerUI(c =>
//             {
//                 c.SwaggerEndpoint("/swagger/v1/swagger.json", "Silo API V1");
//                 c.RoutePrefix = string.Empty; // Swagger UI ngay tại http://localhost:5294
//             });

//             // app.UseEndpoints(endpoints =>
//             // {
//             //     endpoints.MapControllers();
//             //     endpoints.MapHub<SiloHub>("/siloHub"); // 👈 endpoint cho SignalR
//             // });

//             // Map controllers và SignalR Hub
//             app.MapControllers();
//             app.MapHub<SiloHub>("/siloHub");

//             app.Run();
//         }
//     }
// }

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

            // 4. Đăng ký CORS (Đã sửa lỗi để tương thích với SignalR)
            builder.Services.AddCors(options =>
            {
                options.AddPolicy("AllowAll", policy => 
                {
                    policy.WithOrigins(
                                "http://localhost",
                                "http://192.168.1.22",
                                "http://127.0.0.1",
                                "http://localhost:80", // Thêm các domain/IP frontend của khách hàng tại đây
                                "http://192.168.1.22:80" // Thêm các domain/IP frontend của khách hàng tại đây
                           )
                           .AllowAnyMethod()
                           .AllowAnyHeader()
                           .AllowCredentials(); // Khóa bảo mật bắt buộc của SignalR
                });
            });

            // 5. Đăng ký SignalR
            builder.Services.AddSignalR();

            var app = builder.Build();

            // --- Middleware Pipeline ---
            
            // Xử lý lỗi cục bộ hoặc môi trường Production nếu cần
            if (!app.Environment.IsDevelopment())
            {
                app.UseDeveloperExceptionPage(); // Hoặc app.UseExceptionHandler() tùy nhu cầu debug của bạn
            }

            app.UseRouting();
            
            // CORS phải đặt ĐÚNG vị trí này
            app.UseCors("AllowAll");
            
            app.UseAuthorization();

            // Cấu hình Swagger UI (Sẽ hiển thị ngay khi vào http://localhost:5294)
            app.UseSwagger();
            app.UseSwaggerUI(c =>
            {
                c.SwaggerEndpoint("/swagger/v1/swagger.json", "Silo API V1");
                c.RoutePrefix = string.Empty; 
            });

            // Map Routes & Endpoints công nghệ mới (.NET 6+)
            app.MapControllers();
            app.MapHub<SiloHub>("/siloHub");

            app.Run();
        }
    }
}