import 'package:intl/intl.dart';

import '../models/silo_history_model.dart';

enum _TrendDirection { up, down, flat }

class CompressedStatisticsReportItem {
  final SiloHistoryModel milestone;
  final SiloHistoryModel? previousMilestone;
  final double weightBefore;
  final double weightAfter;
  final String weightChangeText;
  final String timeRangeText;
  final String detailText;

  const CompressedStatisticsReportItem({
    required this.milestone,
    required this.previousMilestone,
    required this.weightBefore,
    required this.weightAfter,
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

  // Không đủ dữ liệu để tạo biến động thực tế.
  if (sorted.length < 2) {
    return const <CompressedStatisticsReportItem>[];
  }

  final milestones = <SiloHistoryModel>[];
  _TrendDirection? currentTrend;
  var lastMovingIndex = -1;

  for (var i = 1; i < sorted.length; i++) {
    final previous = sorted[i - 1];
    final current = sorted[i];
    final delta = current.weightNow - previous.weightNow;

    // Bỏ toàn bộ điểm/đoạn đứng yên theo quy tắc dự án.
    if (delta == 0) {
      continue;
    }

    final nextTrend = _detectTrend(
      previousWeight: previous.weightNow,
      currentWeight: current.weightNow,
    );

    if (currentTrend == null) {
      _addIfNewMilestone(milestones, previous);
      currentTrend = nextTrend;
    } else if (nextTrend != currentTrend) {
      // Khi đổi hướng, chốt điểm kết thúc của xu hướng trước.
      _addIfNewMilestone(milestones, previous);
      currentTrend = nextTrend;
    }

    lastMovingIndex = i;
  }

  // Không có biến động thực tế nào.
  if (lastMovingIndex < 0) {
    return const <CompressedStatisticsReportItem>[];
  }

  // Chốt điểm cuối của đợt xu hướng cuối cùng.
  _addIfNewMilestone(milestones, sorted[lastMovingIndex]);

  if (milestones.length < 2) {
    return const <CompressedStatisticsReportItem>[];
  }

  final result = <CompressedStatisticsReportItem>[];
  for (var i = 1; i < milestones.length; i++) {
    final current = milestones[i];
    final previous = milestones[i - 1];
    final delta = current.weightNow - previous.weightNow;

    // Chặn tuyệt đối mọi bản ghi 0 kg ở đầu ra.
    if (delta == 0) {
      continue;
    }

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
      weightBefore: previous?.weightNow ?? milestone.weightNow,
      weightAfter: milestone.weightNow,
      weightChangeText: weightChangeText,
      timeRangeText: timeRangeText,
      detailText: detailText,
    );
  } catch (_) {
    return CompressedStatisticsReportItem(
      milestone: milestone,
      previousMilestone: previous,
      weightBefore: 0,
      weightAfter: 0,
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
