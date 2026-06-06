import 'package:flutter/material.dart';
import 'silo_module.dart'; // Import module đã tạo

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

  void _select(int index, String label) {
    setState(() {
      _selectedIndex = index;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
  }

  @override
  Widget build(BuildContext context) {
    const sidebarWidth = 280.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // ===== Header (custom) =====
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
                        child: const Icon(
                          Icons.cloud,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Silo Dashboard',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Giám sát & Điều khiển hệ thống cân định lượng',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: const [
                          Icon(Icons.notifications, color: Colors.black54),
                          SizedBox(width: 16),
                          Icon(Icons.account_circle, color: Colors.black54),
                        ],
                      ),
                    ],
                  ),
                ),

                // ===== Body: sidebar + content =====
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sidebar
                          Container(
                            width: sidebarWidth,
                            margin: const EdgeInsets.all(16),
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
                                      colors: [
                                        Colors.blue.shade700,
                                        Colors.blue.shade500
                                      ],
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 10,
                                    ),
                                    children: [
                                      _buildSidebarItem(
                                        icon: Icons.dashboard,
                                        label: 'Giám sát',
                                        index: 0,
                                        selectedIndex: _selectedIndex,
                                        onTap: () =>
                                            _select(0, 'Giám sát'),
                                      ),
                                      const SizedBox(height: 10),
                                      _buildSidebarItem(
                                        icon: Icons.settings,
                                        label: 'Điều khiển',
                                        index: 1,
                                        selectedIndex: _selectedIndex,
                                        onTap: () =>
                                            _select(1, 'Điều khiển'),
                                      ),
                                      const SizedBox(height: 10),
                                      _buildSidebarItem(
                                        icon: Icons.bar_chart,
                                        label: 'Báo cáo',
                                        index: 2,
                                        selectedIndex: _selectedIndex,
                                        onTap: () => _select(2, 'Báo cáo'),
                                      ),
                                      const SizedBox(height: 10),
                                      _buildSidebarItem(
                                        icon: Icons.warning,
                                        label: 'Cảnh báo',
                                        index: 3,
                                        selectedIndex: _selectedIndex,
                                        onTap: () =>
                                            _select(3, 'Cảnh báo'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Main content
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                0,
                                0,
                                18,
                                16,
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            final maxWidth =
                                                constraints.maxWidth.isFinite
                                                    ? constraints.maxWidth
                                                    : 1200.0;

                                            // Chốt 1 điểm quan trọng: tránh Wrap tự bẻ dòng.
                                            // Dùng GridView để luôn sắp theo số cột phù hợp với độ rộng.
                                            final crossAxisCount =
                                                maxWidth >= 1200
                                                    ? 4
                                                    : (maxWidth >= 980
                                                        ? 3
                                                        : (maxWidth >= 720
                                                            ? 2
                                                            : 1));

                                            return GridView.count(
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              shrinkWrap: true,
                                              crossAxisCount: crossAxisCount,
                                              crossAxisSpacing: 16,
                                              mainAxisSpacing: 16,
                                              childAspectRatio: 0.98,
                                              children: [
                                                SiloModule(
                                                  name: "Silo 1",
                                                  weight: 1200,
                                                  level: 0.7,
                                                  indicatorId: 'IND-001',
                                                  indicatorPort: 'COM3',
                                                  indicatorMaxLoad: 2000,
                                                  controllerIp:
                                                      '192.168.0.10',
                                                  controllerPort: '502',
                                                  controllerSn: 'SN-001',
                                                ),
                                                SiloModule(
                                                  name: "Silo 2",
                                                  weight: 800,
                                                  level: 0.45,
                                                  indicatorId: 'IND-002',
                                                  indicatorPort: 'COM4',
                                                  indicatorMaxLoad: 1800,
                                                  controllerIp:
                                                      '192.168.0.11',
                                                  controllerPort: '502',
                                                  controllerSn: 'SN-002',
                                                ),
                                                SiloModule(
                                                  name: "Silo 3",
                                                  weight: 1500,
                                                  level: 0.1,
                                                  indicatorId: 'IND-003',
                                                  indicatorPort: 'COM5',
                                                  indicatorMaxLoad: 2500,
                                                  controllerIp:
                                                      '192.168.0.12',
                                                  controllerPort: '502',
                                                  controllerSn: 'SN-003',
                                                ),
                                                SiloModule(
                                                  name: "Silo 4",
                                                  weight: 980,
                                                  level: 0.25,
                                                  indicatorId: 'IND-004',
                                                  indicatorPort: 'COM6',
                                                  indicatorMaxLoad: 1900,
                                                  controllerIp:
                                                      '192.168.0.13',
                                                  controllerPort: '502',
                                                  controllerSn: 'SN-004',
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        const SizedBox(height: 24),
                                        // (đã bỏ bảng thống kê theo yêu cầu)
                                        // Nội dung tiếp theo sẽ được bổ sung theo đúng
                                        // bố cục ảnh Webmau.png
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
}

