import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/controller.dart';
import '../models/indicator.dart';
import '../models/silo.dart';

class SiloModule extends StatefulWidget {
  final String id;
  final double? currentWeight;
  final double maxWeight;
  final double level; // not used for UI (level is calculated from weight/max)
  final List<Indicator> indicators;
  final List<Controller> controllers;
  final List<Silo> silos;

  const SiloModule({
    super.key,
    required this.id,
    required this.currentWeight,
    required this.maxWeight,
    required this.level,
    required this.indicators,
    required this.controllers,
    required this.silos,
  });

  @override
  State<SiloModule> createState() => _SiloModuleState();
}

class _SiloModuleState extends State<SiloModule> {
  double _currentWeight = 0;
  bool _isFetchingScale = false;

  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _currentWeight = widget.currentWeight ?? 0;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _loadScaleValue();
    });

    _loadScaleValue();
  }

  Future<void> _loadScaleValue() async {
    if (_isFetchingScale) return;
    _isFetchingScale = true;

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.baseUrl}/Scales/GetScaleValue?id=1'),
          )
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final value = (data['value'] as num).toDouble();
        setState(() => _currentWeight = value);
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      _isFetchingScale = false;
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Color _getLevelColor(double level01) {
    // keep old thresholds (level01 is 0..1, same as painter)
    if (level01 > 0.5) return Colors.green;
    if (level01 > 0.2) return Colors.yellow.shade700;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Dùng breakpoint theo kích thước thật của màn hình để tránh bị parent ép width nhỏ.
        final screenWidth = MediaQuery.of(context).size.width;

        // Standard breakpoint:
        // - Mobile: <640 (Column)
        // - Desktop/tablet: >=640 (Row)
        final isMobile = screenWidth < 640;


        // Gauge scale (clamp to avoid overflow)
        // Gauge scale dựa theo width thực tế của vùng layout hiện tại.
        // Dù breakpoint dùng screenWidth, kích thước gauge vẫn dùng width từ constraints để không bị quá to/nhỏ.
        final localWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : screenWidth * 0.5;

        final siloWidth = (localWidth * 0.28).clamp(70.0, 130.0);
        final gaugeHeight = (siloWidth * (isMobile ? 1.8 : 2.0))
            .clamp(isMobile ? 160.0 : 220.0, isMobile ? 320.0 : 360.0);


        final sidePadding = isMobile ? 10.0 : 16.0;
        final headerFontSize = isMobile ? 16.0 : 18.0;
        final labelFontSize = isMobile ? 14.0 : 16.0;
        final valueFontSize = (labelFontSize + (isMobile ? 0.0 : 1.0))
            .clamp(13.0, 18.0);

        // Level calculation from user input (Cân Max)
        final maxWeight = (widget.maxWeight > 0) ? widget.maxWeight : 1;
        final currentForLevel = _currentWeight.clamp(0.0, maxWeight);
        final levelPercent = ((currentForLevel / maxWeight) * 100.0).clamp(0.0, 100.0);
        final level01 = (levelPercent / 100.0).clamp(0.0, 1.0);

        final weightValue = _currentWeight != 0
            ? '${_currentWeight.toStringAsFixed(1)} kg'
            : 'Đang tải...';

        final gauge = SizedBox(
          width: siloWidth,
          height: gaugeHeight,
          child: CustomPaint(
            painter: SiloScalePainter(
              level: level01,
              fillColor: _getLevelColor(level01),
            ),
          ),
        );

        final weightInfo = _WeightInfo(
          labelFontSize: labelFontSize,
          valueFontSize: isMobile ? valueFontSize : (valueFontSize + 6).clamp(18.0, 30.0),
          weightValue: weightValue,
          isMobile: isMobile,
        );

        final content = isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: gauge),
                  SizedBox(height: isMobile ? 10 : 12),
                  weightInfo,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(fit: FlexFit.loose, child: Center(child: gauge)),
                  SizedBox(width: localWidth * 0.03),
                  Flexible(fit: FlexFit.loose, child: Align(alignment: Alignment.centerLeft, child: weightInfo)),

                ],
              );

        return SizedBox(
          width: double.infinity,
          child: ConstrainedBox(
            // ensure this widget layout uses the same width the website gives it
            constraints: const BoxConstraints(maxWidth: 1024),
            child: Card(
              elevation: 4,
              margin: const EdgeInsets.all(12),
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                height: isMobile ? 360 : 400,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(sidePadding),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                  children: [
                      Text(

                        widget.id,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: headerFontSize,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Cân Max: ${widget.maxWeight.toStringAsFixed(1)} kg',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 6),
                      content,
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WeightInfo extends StatelessWidget {
  final double labelFontSize;
  final double valueFontSize;
  final String weightValue;
  final bool isMobile;


  const _WeightInfo({
    required this.labelFontSize,
    required this.valueFontSize,
    required this.weightValue,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Số cân',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: labelFontSize,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        SizedBox(height: isMobile ? 6 : 8),
        Text(
          weightValue,
          style: TextStyle(
            fontSize: valueFontSize,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          maxLines: 1,
        ),
      ],
    );
  }
}

class SiloScalePainter extends CustomPainter {
  final double level; // 0..1
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

    final double safeLevel = level.clamp(0.0, 1.0);

    final Path bodyPath = Path()
      ..moveTo(0, bodyTop)
      ..lineTo(0, bodyBottom - ellipseH / 2)
      ..lineTo(w / 2, tipY)
      ..lineTo(w, bodyBottom - ellipseH / 2)
      ..lineTo(w, bodyTop)
      ..close();

    canvas.drawPath(bodyPath, bodyPaint);
    canvas.drawPath(bodyPath, stroke);
    canvas.drawOval(topEllipse, stroke);

    final double totalFillArea = tipY - bodyTop;
    final double fillHeight = (totalFillArea * safeLevel).clamp(0.0, totalFillArea);
    final double fillTop = tipY - fillHeight;

    final Paint fillPaint = Paint()..color = fillColor;

    final Rect fillEllipse = Rect.fromLTWH(
      0,
      fillTop - ellipseH / 2,
      w,
      ellipseH,
    );

    final Path fillPath = Path()
      ..addOval(fillEllipse)
      ..addRect(Rect.fromLTWH(0, fillTop, w, tipY - fillTop));

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
      final double t = i / 5.0;
      final double y = tipY - totalFillArea * t;
      canvas.drawLine(Offset(4, y), Offset(w - 4, y), stroke);

      final tp = TextPainter(
        text: TextSpan(
          text: '${(i * 20)}%',
          style: const TextStyle(color: Colors.black, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(w - tp.width - 2, y - tp.height / 2));
    }

    final String pct = '${(safeLevel * 100).toInt()}%';
    final pctTp = TextPainter(
      text: TextSpan(
        text: pct,
        style: TextStyle(
          color: (safeLevel > 0.25) ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: (w * 0.12).clamp(12.0, 16.0),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    double pctY = fillTop + (bodyBottom - fillTop) / 2 - pctTp.height / 2;
    pctY = pctY.clamp(bodyTop, bodyBottom - pctTp.height);

    canvas.save();
    canvas.clipPath(bodyPath);
    pctTp.paint(canvas, Offset((w - pctTp.width) / 2, pctY));
    canvas.restore();
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

