# TODO - Silo Dashboard (SQL Server)

## Phase 1: Fix/build UI
- [x] Khôi phục `lib/main.dart` về đúng bố cục (Header + Row sidebar | modules | plan).
- [x] Đưa `lib/services/sql_service.dart` về trạng thái an toàn để project build được khi driver SQL chưa tương thích.
- [ ] Xóa/giảm warning unused import và deprecation (không bắt buộc).

## Phase 2: Kết nối SQL thật theo hướng Windows (không dùng API web)
- [ ] Làm một local gateway/proxy chạy trên Windows.
  - Gateway phải trả về JSON `List<Map<String,dynamic>>` đúng schema `Silo.fromMap`.

## Phase 3: Kết nối cho Flutter Web (Chrome)
- [ ] Vì browser không truy cập SQL Server trực tiếp, dùng **proxy local (localhost)** để web gọi.
- [ ] Update `SqlService.fetchSilos()` để gọi localhost proxy (HTTP local).

## Phase 4: Test
- [ ] Chạy `flutter run -d chrome` và kiểm tra hiển thị 2 dòng: Silo1, Silo2.
- [ ] Chạy `flutter run -d windows` (nếu muốn) và kiểm tra tương tự.

