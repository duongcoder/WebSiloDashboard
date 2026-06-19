# Silo Dashboard - Copilot Instructions

## 📋 Tổng Quan Kiến Trúc

Dự án **Silo Dashboard** là một ứng dụng quản lý silo (kho chứa) với kiến trúc **Client-Server**:

### Stack Công Nghệ
- **Frontend**: Flutter (Dart) - Ứng dụng responsive cross-platform (Web, Android, iOS, Windows, Linux, macOS)
- **Backend**: ASP.NET Core 6+ with Entity Framework Core
- **Database**: SQL Server
- **Real-time Communication**: SignalR (WebSocket)
- **HTTP Client**: http package (Dart)

### Cấu Trúc Thư Mục

```
silo_dashboard/
├── lib/                           # Mã nguồn Flutter/Dart
│   ├── main.dart                  # Entry point, thiết lập MaterialApp
│   ├── config/                    # Configuration
│   │   └── app_config.dart       # Cấu hình server IP/port
│   ├── models/                    # Data models
│   │   ├── silo.dart             # Silo model (id, weight, level)
│   │   ├── indicator.dart        # Indicator model
│   │   ├── controller.dart       # Controller model
│   │   └── col_data.dart         # Collected data model
│   ├── services/                  # Business logic & API
│   │   ├── sql_service.dart      # API calls (fetch/create/update)
│   │   └── scale_service.dart    # Scale measurement service
│   └── widgets/                   # UI components
│       ├── silo_module.dart      # Silo display & control
│       ├── indicator_module.dart # Indicator display
│       ├── controller_module.dart# Controller configuration
│       └── col_data_chart.dart   # Data visualization
│
├── backend/                       # ASP.NET Core API
│   └── Backend/
│       ├── Program.cs            # Startup configuration
│       ├── Controllers/          # API endpoints
│       ├── Models/               # C# data models
│       ├── Data/                 # DbContext & migrations
│       ├── Hubs/                 # SignalR hubs
│       └── appsettings.json      # Configuration
│
├── android/                       # Android native code
├── ios/                           # iOS native code
├── web/                           # Web build output
├── windows/                       # Windows native code
├── linux/                         # Linux native code
└── macos/                         # macOS native code
```

## 🎯 Quy Tắc Đặt Tên (Naming Conventions)

### Dart/Flutter

#### Variables & Functions
- **snake_case** cho biến, hàm, và parameters
  ```dart
  String userName;
  double currentWeight;
  Future<List<Silo>> fetchSilos();
  void handlePumpRequest(String mode, double weight);
  ```

#### Classes & Types
- **PascalCase** cho tên class, widget, và model
  ```dart
  class SiloModule extends StatefulWidget { }
  class ApiService { }
  class Silo { }
  ```

#### Constants
- **lowerCamelCase** hoặc UPPER_SNAKE_CASE tùy theo scope
  ```dart
  const String defaultPort = "5294";
  const int timeoutSeconds = 10;
  ```

#### Widget State Classes
- Sử dụng `_[WidgetName]State` pattern
  ```dart
  class _SiloModuleState extends State<SiloModule> { }
  class _DashboardPageState extends State<DashboardPage> { }
  ```

#### Private Members
- Sử dụng prefix underscore `_` cho private
  ```dart
  bool _indicatorExpanded = false;
  late final TextEditingController _pumpWeightController;
  void _handleExpand() { }
  ```

### Backend (C#)

#### PascalCase cho tất cả public members
```csharp
public class Controller { }
public string ControllerId { get; set; }
public async Task<List<Silo>> GetSilos() { }
```

## 📚 Thư Viện Chính & Phiên Bản

### Frontend Dependencies (pubspec.yaml)

| Thư Viện | Phiên Bản | Mục Đích |
|---------|---------|---------|
| `flutter` | SDK | UI framework |
| `fl_chart` | ^0.68.0 | Vẽ biểu đồ (charts) |
| `signalr_core` | ^1.1.0 | Real-time communication (WebSocket) |
| `responsive_framework` | ^1.5.1 | Responsive layout với breakpoints |
| `http` | ^1.6.0 | HTTP requests |
| `cupertino_icons` | ^1.0.8 | iOS style icons |
| `flutter_lints` | ^6.0.0 | Linting rules |

### Backend Dependencies (Backend.csproj)

- **Microsoft.EntityFrameworkCore**: ORM cho database
- **Microsoft.AspNetCore.SignalR**: Real-time communication
- **Newtonsoft.Json**: JSON serialization
- **Swagger/OpenAPI**: API documentation

### Dart SDK Requirement
```
sdk: ^3.12.1
```

## 🏗️ Kiến Trúc Chi Tiết

### 1. Models (Data Transfer Objects)

Mỗi model phải có:
- Constructor với `required` parameters
- `fromJson()` factory constructor để deserialization
- `toJson()` method để serialization

**Ví dụ (Silo model):**
```dart
class Silo {
  final String id;
  final double weight;
  final double level;

  Silo({
    required this.id,
    required this.weight,
    required this.level,
  });

  factory Silo.fromJson(Map<String, dynamic> json) {
    return Silo(
      id: json['id'] ?? '',
      weight: (json['weight'] as num).toDouble(),
      level: (json['level'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'weight': weight,
      'level': level,
    };
  }
}
```

### 2. Services (Business Logic & API)

- `ApiService` (sql_service.dart): Gọi API backend
  - Sử dụng static methods
  - Xử lý timeouts (10 giây)
  - Error handling với Exception
  - Fetch endpoints: `/silos`, `/indicators`, `/controllers`, `/coldata`

- `ScaleService`: Xử lý dữ liệu cân nặng
  - Kết nối SignalR hub
  - Real-time updates

### 3. Widgets

#### Page-level (StatefulWidget)
- `DashboardPage`: Main dashboard

#### Modules (StatefulWidget)
- `SiloModule`: Hiển thị & điều khiển silo
  - TextEditingController cho inputs (pump weight, time)
  - Expandable sections (indicators, controllers)
  - Periodic timer updates

- `IndicatorModule`: Hiển thị indicator status
- `ControllerModule`: Cấu hình controller
- `ColDataChart`: Biểu đồ dữ liệu

### 4. Configuration

**AppConfig (app_config.dart):**
```dart
static String get serverIp {
  // Tự động lấy từ browser URL hoặc localhost
  if (kIsWeb) {
    return Uri.base.host; 
  }
  return "localhost";
}

static const String apiPort = "5294";
static String get baseUrl => "http://$serverIp:$apiPort/api";
```

### 5. Responsive Design

Sử dụng `ResponsiveBreakpoints`:
```dart
breakpoints: [
  const Breakpoint(start: 0, end: 450, name: MOBILE),
  const Breakpoint(start: 451, end: 800, name: TABLET),
  const Breakpoint(start: 801, end: 1920, name: DESKTOP),
  const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
],
```

## 💡 Coding Conventions

### Dart/Flutter

#### Imports
- Nhóm imports: dart, package, relative
```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/silo.dart';
```

#### Comments
- Sử dụng Tiếng Việt trong comments
- `///` cho documentation comments
- `//` cho inline comments

```dart
/// Lấy danh sách Silos từ API
static Future<List<Silo>> fetchSilos() async {
  // Gọi API với timeout 10 giây
  final response = await http.get(...)
    .timeout(const Duration(seconds: 10));
  // ...
}
```

#### Null Safety
- Luôn sử dụng null-safe syntax (`?`, `late`, `required`)
```dart
final double? currentWeight;  // Có thể null
required this.id,             // Bắt buộc
late final TextEditingController _controller; // Khởi tạo sau
```

#### Async/Await
- Ưu tiên `async/await` thay vì `.then()`
```dart
// ✅ Tốt
Future<List<Silo>> fetchSilos() async {
  final response = await http.get(...);
  return ...;
}

// ❌ Tránh
http.get(...).then((response) => ...);
```

#### Error Handling
- Luôn bọc HTTP calls trong try-catch
```dart
try {
  final response = await http.get(uri).timeout(duration);
  if (response.statusCode == 200) {
    return processData(response.body);
  } else {
    throw Exception("Failed to load data");
  }
} catch (e) {
  throw Exception("Error: $e");
}
```

#### Widget Lifecycle
- Sử dụng `initState()` cho initialization
- Sử dụng `dispose()` cho cleanup
```dart
@override
void initState() {
  super.initState();
  _controller = TextEditingController();
  _timer = Timer.periodic(..., (timer) { });
}

@override
void dispose() {
  _controller.dispose();
  _timer?.cancel();
  super.dispose();
}
```

### C# Backend

#### PascalCase cho public APIs
```csharp
public async Task<IActionResult> GetSilos()
public string ControllerId { get; set; }
public decimal Weight { get; set; }
```

#### Entity Relationships
```csharp
public class Silo {
  public string Id { get; set; }
  public decimal Weight { get; set; }
  public decimal Level { get; set; }
  
  // Foreign keys
  public string IndicatorId { get; set; }
  public string ControllerId { get; set; }
}
```

## ✅ NÊN LÀM (Dos)

### Dart/Flutter

1. **Sử dụng const constructors** khi có thể
   ```dart
   const SiloModule(
     key: ValueKey('silo-1'),
     id: 'silo-1',
     ...
   )
   ```

2. **Tách logic khỏi UI**
   - Để business logic trong services
   - Widgets chỉ handle UI & state
   
3. **Sử dụng models & type safety**
   ```dart
   List<Silo> silos = await ApiService.fetchSilos();
   // Không phải List<dynamic> hoặc List<Map>
   ```

4. **Handle timeouts** trong HTTP requests
   ```dart
   .timeout(const Duration(seconds: 10))
   ```

5. **Xử lý null safely**
   ```dart
   final weight = silo.weight ?? 0.0;
   if (currentWeight != null) { ... }
   ```

6. **Sử dụng late final cho dependencies**
   ```dart
   late final TextEditingController _controller;
   
   @override
   void initState() {
     super.initState();
     _controller = TextEditingController();
   }
   ```

7. **Luôn dispose resources**
   ```dart
   _timer?.cancel();
   _controller.dispose();
   _connection?.stop();
   ```

8. **Responsive design cho tất cả device**
   ```dart
   if (context.isMobile) { ... }
   else if (context.isTablet) { ... }
   else { ... }
   ```

9. **Sử dụng factory constructors cho deserialization**
   ```dart
   factory Silo.fromJson(Map<String, dynamic> json) { ... }
   ```

10. **Thêm comments cho non-obvious logic**
    ```dart
    /// Kết nối SignalR hub để lắng nghe real-time updates từ server
    Future<void> connectToHub() async { ... }
    ```

### C# Backend

1. **Luôn sử dụng async/await**
   ```csharp
   public async Task<IActionResult> GetSilos()
   {
     var silos = await _context.Silos.ToListAsync();
   }
   ```

2. **Return appropriate status codes**
   ```csharp
   return Ok(silos);           // 200
   return NotFound();          // 404
   return BadRequest(error);   // 400
   ```

3. **Use Entity Framework properly**
   ```csharp
   var silo = await _context.Silos.FindAsync(id);
   _context.Silos.Add(newSilo);
   await _context.SaveChangesAsync();
   ```

4. **Add input validation**
   ```csharp
   if (string.IsNullOrEmpty(id))
     return BadRequest("ID is required");
   ```

## ❌ KHÔNG NÊN LÀM (Don'ts)

### Dart/Flutter

1. ❌ **Không sử dụng `dynamic` hoặc `Object`**
   ```dart
   // ❌ Tránh
   final data = jsonDecode(response.body) as List;
   
   // ✅ Tốt
   final List<Silo> silos = (jsonDecode(response.body) as List)
     .map((json) => Silo.fromJson(json))
     .toList();
   ```

2. ❌ **Không để build logic trong widgets**
   ```dart
   // ❌ Tránh
   @override
   Widget build(BuildContext context) {
     // API calls, calculations, etc.
   }
   
   // ✅ Tốt
   @override
   void initState() {
     _loadData();
   }
   ```

3. ❌ **Không sử dụng magic numbers**
   ```dart
   // ❌ Tránh
   Timer.periodic(const Duration(seconds: 1), ...);
   
   // ✅ Tốt
   static const int _refreshIntervalSeconds = 1;
   Timer.periodic(Duration(seconds: _refreshIntervalSeconds), ...);
   ```

4. ❌ **Không leak resources**
   ```dart
   // ❌ Tránh - không dispose
   final controller = TextEditingController();
   
   // ✅ Tốt
   late final TextEditingController _controller;
   @override
   void dispose() {
     _controller.dispose();
     super.dispose();
   }
   ```

5. ❌ **Không hardcode URLs**
   ```dart
   // ❌ Tránh
   Uri.parse("http://192.168.1.74:5294/api/silos")
   
   // ✅ Tốt
   Uri.parse("${AppConfig.baseUrl}/silos")
   ```

6. ❌ **Không sử dụng print() cho debugging**
   ```dart
   // ❌ Tránh
   print("Loading silos");
   
   // ✅ Tốt
   debugPrint("Loading silos");
   ```

7. ❌ **Không mix business logic với UI state**
   ```dart
   // ❌ Tránh - tất cả trong Widget
   class SiloModule extends StatefulWidget { }
   
   // ✅ Tốt - tách ApiService & Model
   ```

8. ❌ **Không bỏ qua error handling**
   ```dart
   // ❌ Tránh
   final silos = await ApiService.fetchSilos();
   
   // ✅ Tốt
   try {
     final silos = await ApiService.fetchSilos();
   } catch (e) {
     ScaffoldMessenger.of(context).showSnackBar(...);
   }
   ```

9. ❌ **Không sử dụng FutureBuilder không cần thiết**
   - Sử dụng StateManagement (Provider, Riverpod) nếu state complex
   - FutureBuilder chỉ cho simple cases

10. ❌ **Không commit build artifacts**
    - Flutter build outputs
    - Compiled .NET files (bin/, obj/)

### C# Backend

1. ❌ **Không synchronous blocking**
   ```csharp
   // ❌ Tránh
   var silos = _context.Silos.ToList(); // Blocking
   
   // ✅ Tốt
   var silos = await _context.Silos.ToListAsync();
   ```

2. ❌ **Không expose internal models trực tiếp**
   - Dùng DTOs (Data Transfer Objects)
   
3. ❌ **Không SQL injection**
   ```csharp
   // ❌ Tránh - string interpolation
   $"SELECT * FROM Silos WHERE id = {id}"
   
   // ✅ Tốt - Entity Framework
   var silo = await _context.Silos.FindAsync(id);
   ```

4. ❌ **Không bỏ qua validation**
   ```csharp
   // ✅ Luôn validate input
   if (!ModelState.IsValid)
     return BadRequest(ModelState);
   ```

## 🔧 API Endpoints (Backend)

### Silos
- `GET /api/silos` - Lấy danh sách silos
- `GET /api/silos/{id}` - Lấy silo theo ID
- `POST /api/silos` - Tạo silo mới
- `PUT /api/silos/{id}` - Cập nhật silo
- `DELETE /api/silos/{id}` - Xóa silo

### Indicators
- `GET /api/indicators` - Lấy danh sách indicators
- `GET /api/indicators/{id}` - Lấy indicator theo ID
- `POST /api/indicators` - Tạo indicator mới

### Controllers
- `GET /api/controllers` - Lấy danh sách controllers
- `GET /api/controllers/{id}` - Lấy controller theo ID
- `POST /api/controllers` - Tạo controller mới

### Collected Data
- `GET /api/coldata` - Lấy dữ liệu thu thập
- `POST /api/coldata` - Lưu dữ liệu thu thập

## 📝 Environment Configuration

### AppConfig (Frontend)
```dart
// Tự động detect IP từ browser
static String get serverIp {
  if (kIsWeb) {
    return Uri.base.host; // Lấy từ URL
  }
  return "localhost";
}

static const String apiPort = "5294";
```

### appsettings.json (Backend)
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=...;Database=SiloDb;..."
  }
}
```

## 🧪 Testing Guidelines

### Unit Tests
- Test models, service methods
- Mock HTTP requests

### Widget Tests  
- Test UI components isolation
- Test state changes

### Integration Tests
- Test full flows (API + UI)
- Use realistic data

## 📦 Build & Deploy

### Flutter Web
```bash
flutter build web --release
```

### Flutter Android
```bash
flutter build apk --release
```

### Backend (.NET)
```bash
dotnet publish -c Release
```

## 📞 SignalR Real-time Communication

**HubConnection** sử dụng để:
- Real-time updates từ server
- Pump status updates
- Scale readings

**Example:**
```dart
final connection = HubConnectionBuilder()
  .withUrl("${AppConfig.baseUrl}/scalehub")
  .withAutomaticReconnect()
  .build();

connection.on("ReceiveMessage", (message) {
  // Handle real-time update
});

await connection.start();
```

---

**Version**: 1.0.0  
**Last Updated**: 2026-06-19  
**Language**: Vietnamese/English (Mixed as per project convention)
