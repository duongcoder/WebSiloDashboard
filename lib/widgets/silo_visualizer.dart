import 'package:flutter/material.dart';

class SiloVisualizer extends StatelessWidget {
  final String siloName;
  final double currentWeight;
  final double maxWeight;
  final DateTime? lastUpdatedAt;

  const SiloVisualizer({
    super.key,
    required this.siloName,
    required this.currentWeight,
    required this.maxWeight,
    this.lastUpdatedAt,
  });

  Color _getLevelColor(double level01) {
    if (level01 > 0.5) return const Color(0xFF10B981);
    if (level01 > 0.2) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final localWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : screenWidth * 0.25;

        final isNarrow = localWidth < 220;
        final sidePadding = isNarrow ? 8.0 : 12.0;

        final siloWidth = (localWidth * 0.26).clamp(45.0, 90.0);
        final gaugeHeight = (siloWidth * 1.85).clamp(100.0, 175.0);

        final headerFontSize = isNarrow ? 14.0 : 16.0;
        final labelFontSize = isNarrow ? 11.0 : 13.0;
        final valueFontSize = isNarrow ? 15.0 : 20.0;

        final safeMaxWeight = maxWeight > 0 ? maxWeight : 1.0;
        final safeCurrentWeight = currentWeight.clamp(0.0, safeMaxWeight);
        final levelPercent =
            ((safeCurrentWeight / safeMaxWeight) * 100.0).clamp(0.0, 100.0);
        final level01 = (levelPercent / 100.0).clamp(0.0, 1.0);
        final weightValue = '${safeCurrentWeight.toStringAsFixed(1)} kg';

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
          valueFontSize: valueFontSize,
          weightValue: weightValue,
          isNarrow: isNarrow,
          lastUpdatedAt: lastUpdatedAt,
        );

        final content = isNarrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(child: gauge),
                  const SizedBox(height: 8),
                  weightInfo,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(fit: FlexFit.loose, child: Center(child: gauge)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: weightInfo,
                    ),
                  ),
                ],
              );

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Padding(
            padding: EdgeInsets.all(sidePadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        siloName,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: headerFontSize,
                          color: const Color(0xFF0F172A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Cân Max: ${safeMaxWeight.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontSize: isNarrow ? 10.0 : 11.5,
                            color: const Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(child: content),
              ],
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
  final bool isNarrow;
  final DateTime? lastUpdatedAt;

  const _WeightInfo({
    required this.labelFontSize,
    required this.valueFontSize,
    required this.weightValue,
    required this.isNarrow,
    this.lastUpdatedAt,
  });

  @override
  Widget build(BuildContext context) {
    final timeText = lastUpdatedAt != null
        ? '${lastUpdatedAt!.hour.toString().padLeft(2, '0')}:${lastUpdatedAt!.minute.toString().padLeft(2, '0')}:${lastUpdatedAt!.second.toString().padLeft(2, '0')}'
        : '--:--:--';
    final dateText = lastUpdatedAt != null
        ? '${lastUpdatedAt!.day.toString().padLeft(2, '0')}/${lastUpdatedAt!.month.toString().padLeft(2, '0')}/${lastUpdatedAt!.year}'
        : '--/--/----';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Số cân hiện tại',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: labelFontSize,
              color: const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            weightValue,
            style: TextStyle(
              fontSize: valueFontSize,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 6 : 8,
            vertical: isNarrow ? 3 : 5,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 3),
                    Text(
                      timeText,
                      style: TextStyle(
                        fontSize: isNarrow ? 10 : 11,
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  dateText,
                  style: TextStyle(
                    fontSize: isNarrow ? 9 : 10,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class SiloScalePainter extends CustomPainter {
  final double level;
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
      ..color = const Color(0xFF64748B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final Rect bodyRect = Rect.fromLTWH(0, bodyTop, w, bodyBottom - bodyTop);
    final Paint bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
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

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [fillColor, fillColor.withValues(alpha: 0.85)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, fillTop, w, fillHeight));

    final Rect fillEllipse = Rect.fromLTWH(0, fillTop - ellipseH / 2, w, ellipseH);
    final Path fillPath = Path()
      ..addOval(fillEllipse)
      ..addRect(Rect.fromLTWH(0, fillTop, w, tipY - fillTop));

    canvas.save();
    canvas.clipPath(bodyPath);
    canvas.drawPath(fillPath, fillPaint);
    canvas.restore();

    final Paint topFill = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white.withValues(alpha: 0.6), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(topEllipse);
    canvas.drawOval(topEllipse, topFill);

    for (int i = 1; i <= 5; i++) {
      final double t = i / 5.0;
      final double y = tipY - totalFillArea * t;
      canvas.drawLine(
        Offset(4, y),
        Offset(w - 4, y),
        Paint()
          ..color = const Color(0xFF94A3B8).withValues(alpha: 0.7)
          ..strokeWidth = 1,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: '${(i * 20)}%',
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
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
          color: (safeLevel > 0.25) ? Colors.white : const Color(0xFF0F172A),
          fontWeight: FontWeight.w900,
          fontSize: (w * 0.13).clamp(12.0, 18.0),
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