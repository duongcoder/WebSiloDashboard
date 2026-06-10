import 'package:flutter/material.dart';
import 'widgets/silo_module.dart';
import 'models/silo.dart';
import 'services/sql_service.dart';
import 'package:signalr_core/signalr_core.dart' as signalr;

void main() {
  runApp(const SiloDashboardApp());
}

class SiloDashboardApp extends StatelessWidget {
  const SiloDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Silo Dashboard',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = -1;
  late signalr.HubConnection connection;
  List<Silo> _silos = [];

  // ===== Warning table rows (data derived from silo modules) =====
  List<Map<String, String>> _getWarningRowsFromSilos({
    required List<Map<String, dynamic>> silos,
    required String nowTimeLabel,
  }) {
    String statusByLevel(double level) {
      if (level > 0.2) return 'Đang hoạt động';
      return 'Dừng hoạt động';
    }

    String severityByLevel(double level) {
      if (level < 0.2) return 'Mức thấp';
      if (level <= 0.7) return 'Trung bình';
      return 'Mức cao';
    }

    String contentByLevel(double level) {
      final pct = (level * 100).toInt();
      if (level < 0.2) return 'Mức chứa thấp: $pct%';
      if (level <= 0.7) return 'Mức chứa trung bình: $pct%';
      return 'Mức chứa cao: $pct%';
    }

    return silos.map((silo) {
      final name = (silo['name'] as String?) ?? '';
      final level = (silo['level'] as double?) ?? 0.0;
      final status = statusByLevel(level);
      final severity = severityByLevel(level);
      final content = contentByLevel(level);

      return {
        'time': nowTimeLabel,
        'silo': name,
        'content': content,
        'severity': severity,
        'status': status,
      };
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    initSignalR(); // gọi khi widget khởi tạo
  }

  Future<void> initSignalR() async {
    connection = signalr.HubConnectionBuilder()
        .withUrl('http://localhost:5294/siloHub') // 👈 đúng endpoint backend
        .build();

    // Lắng nghe sự kiện UpdateSilos từ backend
    connection.on('UpdateSilos', (message) {
      if (message != null && message.isNotEmpty) {
        final List<dynamic> data = message[0] as List<dynamic>;
        final silos = data.map((json) => Silo.fromJson(json)).toList();

        setState(() {
          _silos = silos;
        });
      }
    });

    await connection.start();

    if (connection.state == signalr.HubConnectionState.connected) {
      print('SignalR connected');
    } else {
      print('SignalR not connected: ${connection.state}');
    }
  }

  Widget _buildWarningTableCard({
    required List<Map<String, String>> rows,
  }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(left: 0, right: 12, bottom: 12, top: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Text(
              'Bảng cảnh báo',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: DataTable(
                headingRowColor: WidgetStateProperty.resolveWith(
                  (states) => Colors.orange.shade50,
                ),
                dataRowMinHeight: 44,
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('Thời gian')),
                  DataColumn(label: Text('Silo')),
                  DataColumn(label: Text('Nội dung')),
                  DataColumn(label: Text('Mức độ')),
                  DataColumn(label: Text('Trạng thái')),
                ],
                rows: List<DataRow>.generate(rows.length, (index) {
                  final row = rows[index];
                  final status = row['status'] ?? '';
                  final severity = row['severity'] ?? '';

                  return DataRow(
                    cells: [
                      DataCell(Text(row['time'] ?? '')),
                      DataCell(Text(row['silo'] ?? '')),
                      DataCell(Text(row['content'] ?? '')),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _severityColor(severity),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            severity,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(status),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  final List<Map<String, String>> _pumpPlanRows = [
    {
      'time': '08:00 - 08:30',
      'silo': 'Silo 1',
      'material': 'Thóc',
      'qty': '500',
      'status': 'Sẵn sàng',
    },
    {
      'time': '08:30 - 09:00',
      'silo': 'Silo 2',
      'material': 'Bắp',
      'qty': '320',
      'status': 'Chờ',
    },
    {
      'time': '09:00 - 09:30',
      'silo': 'Silo 3',
      'material': 'Gạo',
      'qty': '450',
      'status': 'Lỗi',
    },
    {
      'time': '09:30 - 10:00',
      'silo': 'Silo 4',
      'material': 'Cám',
      'qty': '250',
      'status': 'Đang bơm',
    },
    {
      'time': '10:00 - 10:30',
      'silo': 'Silo 5',
      'material': 'Đậu',
      'qty': '600',
      'status': 'Đã xong',
    },
  ];

  final List<Map<String, String>> _dumpPlanRows = [
    {
      'time': '08:00 - 08:20',
      'silo': 'Silo 1',
      'material': 'Thóc',
      'qty': '260',
      'status': 'Chờ',
    },
    {
      'time': '08:20 - 08:40',
      'silo': 'Silo 3',
      'material': 'Gạo',
      'qty': '180',
      'status': 'Đang bơm',
    },
    {
      'time': '08:40 - 09:00',
      'silo': 'Silo 5',
      'material': 'Đậu',
      'qty': '140',
      'status': 'Đã xong',
    },
  ];

  void _select(int index, String label) {
    setState(() {
      _selectedIndex = index;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required int index,
    required int selectedIndex,
    required VoidCallback onTap,
  }) {
    final bool selected = selectedIndex == index;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? Colors.blue.shade50 : Colors.transparent,
          border: Border.all(
            color: selected ? Colors.blue.shade300 : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? Colors.blue.shade700 : Colors.blue.shade100,
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : Colors.blue.shade800,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.blue.shade900 : Colors.black87,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.chevron_right, color: Colors.blue.shade700, size: 18),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();

    if (s.contains('đang hoạt động') || s.contains('dang hoat dong')) {
      return Colors.green.shade200;
    }
    if (s.contains('dừng hoạt động') || s.contains('dung hoat dong')) {
      return Colors.red.shade200;
    }

    if (s.contains('sẵn') || s.contains('san') || s.contains('sẵn sàng')) {
      return Colors.green.shade200;
    }
    if (s.contains('chờ') || s.contains('cho')) return Colors.yellow.shade200;
    if (s.contains('lỗi') || s.contains('loi')) return Colors.red.shade200;
    if (s.contains('đang bơm') || s.contains('dang bom')) {
      return Colors.green.shade200;
    }
    if (s.contains('đã xong') || s.contains('da xong')) {
      return Colors.blue.shade200;
    }

    return Colors.grey.shade200;
  }

  Color _severityColor(String severity) {
    final s = severity.toLowerCase();
    if (s.contains('mức thấp') || s.contains('muc thap')) return Colors.red.shade200;
    if (s.contains('trung bình') || s.contains('trung binh')) {
      return Colors.yellow.shade200;
    }
    if (s.contains('mức cao') || s.contains('muc cao')) return Colors.green.shade200;
    return Colors.grey.shade200;
  }

  Widget _buildPumpPlanCard() {
    return _buildPlanCard(
      title: 'Danh sách kế hoạch',
      rows: _pumpPlanRows,
      addSnackBarText: 'Đã thêm kế hoạch',
      deleteSnackBarText: 'Đã xóa kế hoạch',
    );
  }

  Widget _buildDumpPlanCard() {
    return _buildPlanCard(
      title: 'Danh sách kế hoạch',
      rows: _dumpPlanRows,
      addSnackBarText: 'Đã thêm kế hoạch xả',
      deleteSnackBarText: 'Đã xóa kế hoạch xả',
    );
  }

  Widget _buildPlanCard({
    required String title,
    required List<Map<String, String>> rows,
    required String addSnackBarText,
    required String deleteSnackBarText,
  }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(left: 0, right: 12, bottom: 12, top: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await showDialog<Map<String, String>>(
                      context: context,
                      builder: (dialogContext) {
                        final timeController = TextEditingController(text: '');
                        final siloController = TextEditingController(text: '');
                        final materialController = TextEditingController(text: '');
                        final qtyController = TextEditingController(text: '');
                        final statusController = TextEditingController(text: 'Chờ');

                        return AlertDialog(
                          title: const Text('Thêm kế hoạch'),
                          content: SingleChildScrollView(
                            child: Column(
                              children: [
                                TextField(
                                  controller: timeController,
                                  decoration: const InputDecoration(labelText: 'Thời gian'),
                                ),
                                TextField(
                                  controller: siloController,
                                  decoration: const InputDecoration(labelText: 'Silo'),
                                ),
                                TextField(
                                  controller: materialController,
                                  decoration: const InputDecoration(labelText: 'Nguyên liệu'),
                                ),
                                TextField(
                                  controller: qtyController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Số lượng'),
                                ),
                                TextField(
                                  controller: statusController,
                                  decoration: const InputDecoration(labelText: 'Trạng thái'),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              child: const Text('Hủy'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(dialogContext).pop({
                                  'time': timeController.text.trim(),
                                  'silo': siloController.text.trim(),
                                  'material': materialController.text.trim(),
                                  'qty': qtyController.text.trim(),
                                  'status': statusController.text.trim(),
                                });
                              },
                              child: const Text('Thêm'),
                            ),
                          ],
                        );
                      },
                    );

                    if (result == null) return;

                    final time = result['time'] ?? '';
                    final silo = result['silo'] ?? '';
                    final material = result['material'] ?? '';
                    final qty = result['qty'] ?? '';
                    final status = result['status'] ?? '';

                    if (time.isEmpty || silo.isEmpty || material.isEmpty || qty.isEmpty || status.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin')),
                      );
                      return;
                    }

                    setState(() {
                      rows.add({
                        'time': time,
                        'silo': silo,
                        'material': material,
                        'qty': qty,
                        'status': status,
                      });
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(addSnackBarText)),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm kế hoạch'),
                ),
              ],
            ),
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: DataTable(
                headingRowColor: WidgetStateProperty.resolveWith(
                  (states) => Colors.blue.shade50,
                ),
                dataRowMinHeight: 44,
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('Thời gian')),
                  DataColumn(label: Text('Silo')),
                  DataColumn(label: Text('Nguyên liệu')),
                  DataColumn(label: Text('Số lượng'), numeric: true),
                  DataColumn(label: Text('Trạng thái')),
                  DataColumn(label: Text('Xóa')),
                ],
                rows: List<DataRow>.generate(rows.length, (index) {
                  final row = rows[index];
                  final status = row['status'] ?? '';

                  return DataRow(
                    cells: [
                      DataCell(Text(row['time'] ?? '')),
                      DataCell(Text(row['silo'] ?? '')),
                      DataCell(Text(row['material'] ?? '')),
                      DataCell(Text(row['qty'] ?? '')),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(status),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          tooltip: 'Xóa kế hoạch',
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              rows.removeAt(index);
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(deleteSnackBarText)),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(double sidebarWidth) {
    return Container(
      width: sidebarWidth,
      margin: const EdgeInsets.only(top: 0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 78,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              gradient: LinearGradient(
                colors: [Colors.blue.shade700, Colors.blue.shade500],
              ),
            ),
            child: const Center(
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              children: [
                _buildSidebarItem(
                  icon: Icons.dashboard_customize,
                  label: 'Tổng quan',
                  index: 0,
                  selectedIndex: _selectedIndex,
                  onTap: () => _select(0, 'Tổng quan'),
                ),
                const SizedBox(height: 10),
                _buildSidebarItem(
                  icon: Icons.storage,
                  label: 'Giám sát silo',
                  index: 1,
                  selectedIndex: _selectedIndex,
                  onTap: () => _select(1, 'Giám sát silo'),
                ),
                const SizedBox(height: 10),
                _buildSidebarItem(
                  icon: Icons.autorenew,
                  label: 'Kế hoạch bơm/xả',
                  index: 2,
                  selectedIndex: _selectedIndex,
                  onTap: () => _select(2, 'Kế hoạch bơm/xả'),
                ),
                const SizedBox(height: 10),
                _buildSidebarItem(
                  icon: Icons.history,
                  label: 'Lịch sử',
                  index: 3,
                  selectedIndex: _selectedIndex,
                  onTap: () => _select(3, 'Lịch sử'),
                ),
                const SizedBox(height: 10),
                _buildSidebarItem(
                  icon: Icons.warning_amber_rounded,
                  label: 'Cảnh báo',
                  index: 4,
                  selectedIndex: _selectedIndex,
                  onTap: () => _select(4, 'Cảnh báo'),
                ),
                const SizedBox(height: 10),
                _buildSidebarItem(
                  icon: Icons.description,
                  label: 'Báo cáo',
                  index: 5,
                  selectedIndex: _selectedIndex,
                  onTap: () => _select(5, 'Báo cáo'),
                ),
                const SizedBox(height: 10),
                _buildSidebarItem(
                  icon: Icons.devices_other,
                  label: 'Thiết bị',
                  index: 6,
                  selectedIndex: _selectedIndex,
                  onTap: () => _select(6, 'Thiết bị'),
                ),
                const SizedBox(height: 10),
                _buildSidebarItem(
                  icon: Icons.settings_applications,
                  label: 'Cài đặt',
                  index: 7,
                  selectedIndex: _selectedIndex,
                  onTap: () => _select(7, 'Cài đặt'),
                ),
                const SizedBox(height: 10),
                _buildSidebarItem(
                  icon: Icons.group,
                  label: 'Quản lý người dùng',
                  index: 8,
                  selectedIndex: _selectedIndex,
                  onTap: () => _select(8, 'Quản lý người dùng'),
                ),
              ],
            ),
          ),
        ]
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const sidebarWidth = 280.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: _silos.isEmpty
          ? FutureBuilder<List<Silo>>(
              future: ApiService.fetchSilos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No silos found'));
                }

                // Khi có dữ liệu ban đầu
                _silos = snapshot.data!;
                return _buildDashboard(sidebarWidth);
              },
            )
          : _buildDashboard(sidebarWidth), // realtime cập nhật từ SignalR
    );
  }

  Widget _buildDashboard(double sidebarWidth) {
    return Column(
      children: [
        // ===== Header =====
        Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            border: Border.all(color: Colors.blue.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.shade700,
                ),
                child: const Icon(Icons.cloud, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Silo Dashboard',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Giám sát & Điều khiển hệ thống cân định lượng',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.notifications, color: Colors.black54),
                  SizedBox(width: 16),
                  Icon(Icons.account_circle, color: Colors.black54),
                ],
              ),
            ],
          ),
        ),

        // ===== Body: sidebar | modules | plan =====
        Expanded(
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sidebar
                  _buildSidebar(sidebarWidth),

                  const SizedBox(width: 16),

                  // Dashboard Stats | Modules | Plan (GridView realtime)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ===== Dashboard Stats =====
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Expanded(child: _buildStatCard("Tổng khối lượng", "1,245.32 tấn", Colors.blue)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildStatCard("Silo hoạt động", "22/24", Colors.green)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildStatCard("Silo mức thấp", "3 silo", Colors.orange)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildStatCard("Cảnh báo", "5 cảnh báo", Colors.red)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildStatCard("Lượng ăn hôm nay", "18.52 tấn", Colors.purple)),
                            ],
                          ),
                        ),

                        // ===== Modules + Plan =====
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Modules
                              Expanded(
                                child: SingleChildScrollView(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final maxWidth = constraints.maxWidth.isFinite
                                          ? constraints.maxWidth
                                          : 1200.0;
                                      final crossAxisCount = maxWidth >= 1200
                                          ? 4
                                          : (maxWidth >= 980
                                              ? 3
                                              : (maxWidth >= 720 ? 2 : 1));

                                      return Padding(
                                        padding: const EdgeInsets.only(right: 12),
                                        child: GridView.count(
                                          physics: const NeverScrollableScrollPhysics(),
                                          shrinkWrap: true,
                                          crossAxisCount: crossAxisCount,
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 16,
                                          childAspectRatio: 0.98,
                                          children: _silos.map((silo) {
                                            return SiloModule(
                                              name: silo.id,
                                              weight: silo.weight,
                                              level: silo.level,
                                              indicatorId: silo.indicatorId,
                                              indicatorPort: silo.indicatorPort,
                                              indicatorMaxLoad: silo.indicatorMaxLoad,
                                              controllerIp: silo.controllerIp,
                                              controllerPort: silo.controllerPort,
                                              controllerSn: silo.controllerSn,
                                            );
                                          }).toList(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),

                              // Plan
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 620),
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.only(left: 6, top: 8, bottom: 8),
                                        child: const Text(
                                          'Kế hoạch Bơm',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                                      _buildPumpPlanCard(),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.only(left: 6, top: 8, bottom: 8),
                                        child: const Text(
                                          'Kế hoạch Xả',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                                      _buildDumpPlanCard(),
                                      _buildWarningTableCard(
                                        rows: _getWarningRowsFromSilos(
                                          silos: _silos.map((s) => {
                                            'name': s.id,
                                            'level': s.level,
                                          }).toList(),
                                          nowTimeLabel: 'Ngay hiện tại',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ), 
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
