using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.NewtonsoftJson;
using Microsoft.EntityFrameworkCore;
using Microsoft.OpenApi.Models;
using Backend.Data;   // nơi chứa SiloDbContext
using Backend.Models;
using Backend.Hubs;

namespace Backend
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);

            // Đăng ký DbContext với SQL Server
            builder.Services.AddDbContext<SiloDbContext>(options =>
                options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

            // Đăng ký Controllers
            builder.Services.AddControllers()
                .AddNewtonsoftJson(options =>
                {
                    options.SerializerSettings.ReferenceLoopHandling = Newtonsoft.Json.ReferenceLoopHandling.Ignore;
                });

            // Đăng ký Swagger
            builder.Services.AddEndpointsApiExplorer();
            builder.Services.AddSwaggerGen(c =>
            {
                c.SwaggerDoc("v1", new OpenApiInfo
                {
                    Title = "Silo API",
                    Version = "v1",
                    Description = "API quản lý silo"
                });
            });

            // Đăng ký CORS
            builder.Services.AddCors(options =>
            {
                options.AddPolicy("AllowAll",
                    policy => policy.AllowAnyOrigin()
                                    .AllowAnyMethod()
                                    .AllowAnyHeader());
            });

            builder.Services.AddSignalR();

            var app = builder.Build();

            // Middleware pipeline
            // app.UseHttpsRedirection();
            app.UseRouting();
            app.UseCors("AllowAll");
            app.UseAuthorization();

            // Swagger middleware
            app.UseSwagger();
            app.UseSwaggerUI(c =>
            {
                c.SwaggerEndpoint("/swagger/v1/swagger.json", "Silo API V1");
                c.RoutePrefix = string.Empty; // Swagger UI ngay tại http://localhost:5294
            });

            // app.UseEndpoints(endpoints =>
            // {
            //     endpoints.MapControllers();
            //     endpoints.MapHub<SiloHub>("/siloHub"); // 👈 endpoint cho SignalR
            // });

            // Map controllers và SignalR Hub
            app.MapControllers();
            app.MapHub<SiloHub>("/siloHub");

            app.Run();
        }
    }
}
