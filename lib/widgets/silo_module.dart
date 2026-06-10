import 'package:flutter/material.dart';

class SiloModule extends StatefulWidget {
  final String name;
  final double weight;
  /// phần trăm đầy silo (0.0 - 1.0)
  final double level;

  final String indicatorId;
  final String indicatorPort;
  final double indicatorMaxLoad;

  final String controllerIp;
  final int controllerPort;
  final String controllerSn;

  const SiloModule({
    super.key,
    required this.name,
    required this.weight,
    required this.level,
    required this.indicatorId,
    required this.indicatorPort,
    required this.indicatorMaxLoad,
    required this.controllerIp,
    required this.controllerPort,
    required this.controllerSn,
  });

  @override
  State<SiloModule> createState() => _SiloModuleState();
}

class _SiloModuleState extends State<SiloModule> {
  bool _indicatorExpanded = false;
  bool _controllerExpanded = false;

  late final TextEditingController _pumpWeightController;
  late final TextEditingController _pumpTimeController;
  String _pumpMode = 'fast';

  late final TextEditingController _indicatorIdController;
  late final TextEditingController _indicatorPortController;
  late final TextEditingController _indicatorMaxLoadController;

  late final TextEditingController _controllerIpController;
  late final TextEditingController _controllerPortController;
  late final TextEditingController _controllerSnController;

  bool _editingIndicatorId = false;
  bool _editingIndicatorPort = false;
  bool _editingIndicatorMaxLoad = false;

  bool _editingControllerIp = false;
  bool _editingControllerPort = false;
  bool _editingControllerSn = false;

  @override
  void initState() {
    super.initState();

    _pumpWeightController = TextEditingController();
    _pumpTimeController = TextEditingController();

    _indicatorIdController = TextEditingController(text: widget.indicatorId);
    _indicatorPortController = TextEditingController(text: widget.indicatorPort);
    _indicatorMaxLoadController =
        TextEditingController(text: widget.indicatorMaxLoad.toString());

    _controllerIpController = TextEditingController(text: widget.controllerIp);
    _controllerPortController = TextEditingController(text: widget.controllerPort.toString());
    _controllerSnController = TextEditingController(text: widget.controllerSn);
  }

  Color getLevelColor() {
    if (widget.level > 0.5) return Colors.green;
    if (widget.level > 0.2) return Colors.yellow.shade700;
    return Colors.red;
  }

  Widget _buildEditableRow({
    required String label,
    required TextEditingController controller,
    required bool editing,
    required VoidCallback onTapEdit,
    required ValueChanged<String> onSubmit,
    required VoidCallback onCancel,
    bool alignRight = false,
  }) {
    final TextStyle labelStyle =
        const TextStyle(fontSize: 13, color: Colors.black54);
    final TextStyle valueStyle =
        const TextStyle(fontSize: 13, fontWeight: FontWeight.w600);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('$label:', style: labelStyle),
        const SizedBox(width: 10),
        Flexible(
          fit: FlexFit.loose,
          child: editing
              ? TextField(
                  controller: controller,
                  autofocus: true,
                  textAlign: alignRight ? TextAlign.right : TextAlign.left,
                  style: valueStyle,
                  onSubmitted: onSubmit,
                  onEditingComplete: onCancel,
                )
              : InkWell(
                  onTap: onTapEdit,
                  child: Text(
                    controller.text,
                    textAlign: alignRight ? TextAlign.right : TextAlign.left,
                    style: valueStyle,
                    softWrap: true,
                  ),
                ),
        ),
      ],
    );
  }

  void _toggleIndicator() => setState(() => _indicatorExpanded = !_indicatorExpanded);
  void _toggleController() => setState(() => _controllerExpanded = !_controllerExpanded);

  void _showPumpDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text(
                'Cài đặt Bơm',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _pumpWeightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Khối lượng (kg)',
                        hintText: 'Nhập khối lượng',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pumpTimeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Thời gian (phút)',
                        hintText: 'Nhập thời gian',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    RadioListTile<String>(
                      title: const Text('Bơm nhanh'),
                      value: 'fast',
                      groupValue: _pumpMode,
                      onChanged: (v) {
                        if (v == null) return;
                        setStateDialog(() => _pumpMode = v);
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Bơm chậm'),
                      value: 'slow',
                      groupValue: _pumpMode,
                      onChanged: (v) {
                        if (v == null) return;
                        setStateDialog(() => _pumpMode = v);
                      },
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
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Bơm: ${_pumpWeightController.text} kg, '
                          '${_pumpTimeController.text} phút, '
                          '${_pumpMode == "fast" ? "Bơm nhanh" : "Bơm chậm"}',
                        ),
                      ),
                    );
                  },
                  child: const Text('Xác nhận'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _pumpWeightController.dispose();
    _pumpTimeController.dispose();

    _indicatorIdController.dispose();
    _indicatorPortController.dispose();
    _indicatorMaxLoadController.dispose();

    _controllerIpController.dispose();
    _controllerPortController.dispose();
    _controllerSnController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final moduleWidth =
          constraints.maxWidth.isFinite ? constraints.maxWidth : 420.0;

      final siloWidth = (moduleWidth * 0.28).clamp(70.0, 130.0).toDouble();
      final indicatorMinWidth = 130.0;
      final indicatorMaxWidth = (moduleWidth * 0.8).clamp(140.0, 320.0).toDouble();

      return SizedBox(
        width: double.infinity,
        // Cho phép toàn bộ Card (khung bao module) scroll
        child: Card(
          elevation: 4,
          margin: const EdgeInsets.all(12),
          clipBehavior: Clip.hardEdge,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: _toggleIndicator,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue.shade100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Indicator',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    Icon(
                                      _indicatorExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      color: Colors.blue.shade800,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              alignment: Alignment.topLeft,
                              child: _indicatorExpanded
                                  ? ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: indicatorMinWidth,
                                        maxWidth: indicatorMaxWidth,
                                        maxHeight: 180,
                                      ),
                                      child: SingleChildScrollView(
                                        child: Container(
                                          margin:
                                              const EdgeInsets.only(top: 8),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: Colors.grey.shade300),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              _buildEditableRow(
                                                label: 'ID',
                                                controller: _indicatorIdController,
                                                editing: _editingIndicatorId,
                                                onTapEdit: () => setState(() =>
                                                    _editingIndicatorId = true),
                                                onSubmit: (val) => setState(() {
                                                  _indicatorIdController.text = val;
                                                  _editingIndicatorId = false;
                                                }),
                                                onCancel: () => setState(() =>
                                                    _editingIndicatorId = false),
                                              ),
                                              const SizedBox(height: 6),
                                              _buildEditableRow(
                                                label: 'Port',
                                                controller: _indicatorPortController,
                                                editing: _editingIndicatorPort,
                                                onTapEdit: () => setState(() =>
                                                    _editingIndicatorPort = true),
                                                onSubmit: (val) => setState(() {
                                                  _indicatorPortController.text = val;
                                                  _editingIndicatorPort = false;
                                                }),
                                                onCancel: () => setState(() =>
                                                    _editingIndicatorPort = false),
                                              ),
                                              const SizedBox(height: 6),
                                              _buildEditableRow(
                                                label: 'Max Load',
                                                controller:
                                                    _indicatorMaxLoadController,
                                                editing:
                                                    _editingIndicatorMaxLoad,
                                                onTapEdit: () => setState(() =>
                                                    _editingIndicatorMaxLoad = true),
                                                onSubmit: (val) => setState(() {
                                                  _indicatorMaxLoadController.text = val;
                                                  _editingIndicatorMaxLoad = false;
                                                }),
                                                onCancel: () => setState(() =>
                                                    _editingIndicatorMaxLoad = false),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: siloWidth,
                              height: siloWidth * 2.0,
                              child: CustomPaint(
                                painter: SiloScalePainter(
                                  level: widget.level,
                                  fillColor: getLevelColor(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerRight,
                              child: IntrinsicWidth(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    InkWell(
                                      onTap: _toggleController,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.shade50,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.teal.shade100),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Bộ Điều Khiển',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14),
                                            ),
                                            Icon(
                                              _controllerExpanded
                                                  ? Icons.expand_less
                                                  : Icons.expand_more,
                                              color: Colors.teal.shade800,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    AnimatedSize(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      curve: Curves.easeInOut,
                                      alignment: Alignment.topRight,
                                      child: _controllerExpanded
                                          ? ConstrainedBox(
                                              constraints: BoxConstraints(
                                                minWidth: indicatorMinWidth,
                                                maxWidth: indicatorMaxWidth,
                                                maxHeight: 150,
                                              ),
                                              child: SingleChildScrollView(
                                                child: Container(
                                                  margin: const EdgeInsets.only(top: 8),
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                    border: Border.all(
                                                        color: Colors.grey.shade300),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.stretch,
                                                    children: [
                                                      _buildEditableRow(
                                                        label: 'IP',
                                                        controller: _controllerIpController,
                                                        editing: _editingControllerIp,
                                                        onTapEdit: () => setState(() =>
                                                            _editingControllerIp = true),
                                                        onSubmit: (val) => setState(() {
                                                          _controllerIpController.text = val;
                                                          _editingControllerIp = false;
                                                        }),
                                                        onCancel: () => setState(() =>
                                                            _editingControllerIp = false),
                                                        alignRight: true,
                                                      ),
                                                      const SizedBox(height: 6),
                                                      _buildEditableRow(
                                                        label: 'Port',
                                                        controller: _controllerPortController,
                                                        editing: _editingControllerPort,
                                                        onTapEdit: () => setState(() =>
                                                            _editingControllerPort = true),
                                                        onSubmit: (val) => setState(() {
                                                          _controllerPortController.text = val;
                                                          _editingControllerPort = false;
                                                        }),
                                                        onCancel: () => setState(() =>
                                                            _editingControllerPort = false),
                                                        alignRight: true,
                                                      ),
                                                      const SizedBox(height: 6),
                                                      _buildEditableRow(
                                                        label: 'SN',
                                                        controller: _controllerSnController,
                                                        editing: _editingControllerSn,
                                                        onTapEdit: () => setState(() =>
                                                            _editingControllerSn = true),
                                                        onSubmit: (val) => setState(() {
                                                          _controllerSnController.text = val;
                                                          _editingControllerSn = false;
                                                        }),
                                                        onCancel: () => setState(() =>
                                                            _editingControllerSn = false),
                                                        alignRight: true,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Số cân:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${widget.weight.toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.black87),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                    minimumSize: Size(
                                      (moduleWidth * 0.30).clamp(40.0, 80.0),
                                      36,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 6),
                                    textStyle: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  onPressed: () {},
                                  child: const Text('Start'),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade700,
                                    foregroundColor: Colors.white,
                                    minimumSize: Size(
                                      (moduleWidth * 0.30).clamp(40.0, 80.0),
                                      36,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 6),
                                    textStyle: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  onPressed: () {},
                                  child: const Text('Stop'),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade700,
                                    foregroundColor: Colors.white,
                                    minimumSize: Size(
                                      (moduleWidth * 0.30).clamp(40.0, 80.0),
                                      36,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 6),
                                    textStyle: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  onPressed: _showPumpDialog,
                                  child: const Text('Bơm'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class SiloScalePainter extends CustomPainter {
  final double level; // 0.0 - 1.0
  final Color fillColor;

  SiloScalePainter({required this.level, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final double ellipseH = (w * 0.22).clamp(10.0, w * 0.25);
    final double bodyTop = ellipseH / 2;
    final double bodyBottom = h - ellipseH / 2;

    final Paint stroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final Rect bodyRect = Rect.fromLTWH(0, bodyTop, w, bodyBottom - bodyTop);
    final Paint bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.grey.shade200, Colors.grey.shade400],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(bodyRect);

    final Rect topEllipse = Rect.fromLTWH(0, 0, w, ellipseH);
    final double tipY = h;

    Path bodyPath = Path();
    bodyPath.moveTo(0, bodyTop);
    bodyPath.lineTo(0, bodyBottom - ellipseH / 2);
    bodyPath.lineTo(w / 2, tipY);
    bodyPath.lineTo(w, bodyBottom - ellipseH / 2);
    bodyPath.lineTo(w, bodyTop);
    bodyPath.close();

    canvas.drawPath(bodyPath, bodyPaint);
    canvas.drawPath(bodyPath, stroke);
    canvas.drawOval(topEllipse, stroke);

    final double totalFillArea = tipY - bodyTop;
    final double fillHeight =
        (totalFillArea * level).clamp(0.0, totalFillArea);
    final double fillTop = tipY - fillHeight;

    final Paint fillPaint = Paint()..color = fillColor;
    final Rect fillEllipse = Rect.fromLTWH(0, fillTop - ellipseH / 2, w, ellipseH);

    Path fillPath = Path();
    fillPath.addOval(fillEllipse);
    fillPath.addRect(Rect.fromLTWH(0, fillTop, w, tipY - fillTop));

    canvas.save();
    canvas.clipPath(bodyPath);
    canvas.drawPath(fillPath, fillPaint);
    canvas.restore();

    final Paint topFill = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white.withAlpha(153), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(topEllipse);
    canvas.drawOval(topEllipse, topFill);

    for (int i = 1; i <= 5; i++) {
      double t = i / 5.0;
      double y = tipY - totalFillArea * t;
      canvas.drawLine(Offset(4, y), Offset(w - 4, y), stroke);

      final tp = TextPainter(
        text: TextSpan(
          text: '${(i * 20)}%',
          style: const TextStyle(color: Colors.black, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )
        ..layout();

      tp.paint(canvas, Offset(w + 6, y - tp.height / 2));
    }

    final String pct = '${(level * 100).toInt()}%';
    final pctTp = TextPainter(
      text: TextSpan(
        text: pct,
        style: TextStyle(
          color: (level > 0.25) ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      textDirection: TextDirection.ltr,
    )
      ..layout();

    double pctY = fillTop + (bodyBottom - fillTop) / 2 - pctTp.height / 2;
    pctY = pctY.clamp(bodyTop, bodyBottom - pctTp.height);
    pctTp.paint(canvas, Offset((w - pctTp.width) / 2, pctY));
  }

  @override
  bool shouldRepaint(covariant SiloScalePainter oldDelegate) {
    return oldDelegate.level != level || oldDelegate.fillColor != fillColor;
  }
}

class TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

