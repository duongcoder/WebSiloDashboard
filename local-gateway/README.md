# Local SQL Gateway (C#)

Mục tiêu: Flutter Web (Chrome) gọi tới `http://localhost:PORT/silos` để lấy dữ liệu từ SQL Server, tránh việc browser truy cập trực tiếp SQL.

## Setup nhanh
1. Cài [.NET SDK](https://dotnet.microsoft.com/download)
2. Chạy gateway (cấu hình connection string)

## Cách chạy
Từ thư mục `local-gateway`:
- Chỉ định environment:
  - `SQL_CONNECTION_STRING` = connection string SQL Server
  - `PORT` = cổng gateway (mặc định 5005)

Ví dụ (PowerShell):
```powershell
$env:PORT='5005'
$env:SQL_CONNECTION_STRING='Server=localhost,1433;Database=silo_db;User Id=sa;Password=your_password;TrustServerCertificate=True;'

dotnet run
```

Sau đó Flutter Web gọi:
- `http://localhost:5005/health`
- `http://localhost:5005/silos`


## Endpoints
- GET /silos
  Trả về JSON: `List<Silo>` với các field:
  `id, weight, level, indicatorId, indicatorPort, indicatorMaxLoad, controllerIp, controllerPort, controllerSn`

## Cấu hình
Cập nhật các biến môi trường hoặc file config trong dự án gateway.

