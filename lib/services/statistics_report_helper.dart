import 'package:intl/intl.dart';

import '../models/silo_history_model.dart';

enum _TrendDirection { up, down, flat }

class CompressedStatisticsReportItem {
  final SiloHistoryModel milestone;
  final SiloHistoryModel? previousMilestone;
  final String weightChangeText;
  final String timeRangeText;
  final String detailText;

  const CompressedStatisticsReportItem({
    required this.milestone,
    required this.previousMilestone,
    required this.weightChangeText,
    required this.timeRangeText,
    required this.detailText,
  });
}

/// Nén dữ liệu lịch sử theo từng đợt xu hướng (tăng/giảm/đứng yên)
/// để phục vụ bảng "Báo cáo thống kê".
///
/// Thuật toán:
/// 1) Sort tăng dần theo thời gian.
/// 2) Duyệt 1 lần để gom trend liên tục.
/// 3) Chỉ giữ các mốc: điểm đầu ban đầu + điểm kết thúc mỗi trend.
/// 4) Từ các mốc tạo bản ghi báo cáo với delta/time-range/detail.
List<CompressedStatisticsReportItem> generateCompressedStatisticsReport(
  List<SiloHistoryModel> historyList,
) {
  if (historyList.isEmpty) return const <CompressedStatisticsReportItem>[];

  final sorted = [...historyList]
    ..sort((a, b) {
      final byTime = a.time.compareTo(b.time);
      if (byTime != 0) return byTime;
      return a.id.compareTo(b.id);
    });

  // Theo yêu cầu: < 2 phần tử thì giữ nguyên danh sách (không nén thêm).
  if (sorted.length < 2) {
    final only = sorted.first;
    return <CompressedStatisticsReportItem>[
      _buildReportItem(milestone: only, previous: null),
    ];
  }

  final milestones = <SiloHistoryModel>[sorted.first];
  var currentTrend = _detectTrend(
    previousWeight: sorted.first.weightNow,
    currentWeight: sorted[1].weightNow,
  );

  for (var i = 2; i < sorted.length; i++) {
    final nextTrend = _detectTrend(
      previousWeight: sorted[i - 1].weightNow,
      currentWeight: sorted[i].weightNow,
    );

    if (nextTrend != currentTrend) {
      _addIfNewMilestone(milestones, sorted[i - 1]);
      currentTrend = nextTrend;
    }
  }

  _addIfNewMilestone(milestones, sorted.last);

  final result = <CompressedStatisticsReportItem>[];
  for (var i = 0; i < milestones.length; i++) {
    final current = milestones[i];
    final previous = i > 0 ? milestones[i - 1] : null;
    result.add(_buildReportItem(milestone: current, previous: previous));
  }

  return result;
}

void _addIfNewMilestone(List<SiloHistoryModel> milestones, SiloHistoryModel candidate) {
  if (milestones.isEmpty) {
    milestones.add(candidate);
    return;
  }

  final last = milestones.last;
  final sameRecord = last.id == candidate.id && last.time == candidate.time;
  if (!sameRecord) {
    milestones.add(candidate);
  }
}

_TrendDirection _detectTrend({
  required double previousWeight,
  required double currentWeight,
}) {
  if (currentWeight > previousWeight) return _TrendDirection.up;
  if (currentWeight < previousWeight) return _TrendDirection.down;
  return _TrendDirection.flat;
}

CompressedStatisticsReportItem _buildReportItem({
  required SiloHistoryModel milestone,
  required SiloHistoryModel? previous,
}) {
  try {
    final fromTime = previous?.time ?? milestone.time;
    final toTime = milestone.time;
    final delta = milestone.weightNow - (previous?.weightNow ?? milestone.weightNow);
    final deltaAbs = delta.abs();
    final duration = toTime.difference(fromTime).abs();

    final dateText = DateFormat('dd/MM/yyyy').format(toTime.toLocal());
    final fromText = DateFormat('HH:mm:ss').format(fromTime.toLocal());
    final toText = DateFormat('HH:mm:ss').format(toTime.toLocal());

    final timeRangeText = 'Từ $fromText đến $toText - $dateText';
    final weightChangeText = _formatSignedKg(delta);
    final durationText = '${duration.inMinutes} phút';

    String detailText;
    if (delta > 0) {
      detailText = 'Khối lượng tăng thêm ${_formatUnsignedKg(deltaAbs)} trong $durationText';
    } else if (delta < 0) {
      detailText = 'Khối lượng giảm đi ${_formatUnsignedKg(deltaAbs)} trong $durationText';
    } else {
      detailText = 'Khối lượng không đổi trong $durationText';
    }

    return CompressedStatisticsReportItem(
      milestone: milestone,
      previousMilestone: previous,
      weightChangeText: weightChangeText,
      timeRangeText: timeRangeText,
      detailText: detailText,
    );
  } catch (_) {
    return CompressedStatisticsReportItem(
      milestone: milestone,
      previousMilestone: previous,
      weightChangeText: '0 kg',
      timeRangeText: 'Từ --:--:-- đến --:--:-- - --/--/----',
      detailText: 'Khối lượng không đổi trong 0 phút',
    );
  }
}

String _formatSignedKg(double value) {
  final rounded = _compactNumber(value);
  if (value > 0) return '+$rounded kg';
  if (value < 0) return '$rounded kg';
  return '0 kg';
}

String _formatUnsignedKg(double value) {
  return '${_compactNumber(value.abs())} kg';
}

String _compactNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}
