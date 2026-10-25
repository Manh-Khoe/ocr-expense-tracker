import 'dart:math';
import 'package:flutter/material.dart';

/// Bảng màu mặc định cho các danh mục
const Map<String, Color> kCategoryColors = {
  'Food': Colors.deepOrange,
  'Study': Colors.blue,
  'Travel': Colors.teal,
  'Gear': Colors.purple,
  'Entertainment': Colors.pink,
};

/// CustomPainter vẽ Biểu đồ tròn phân bổ chi tiêu theo danh mục
/// Tự động vẽ các nan quạt tương ứng với tỷ lệ % và khoét lỗ donut ở tâm
class PieChartPainter extends CustomPainter {
  final Map<String, double> categoryTotals;
  final Map<String, Color> colors;

  PieChartPainter({
    required this.categoryTotals,
    this.colors = kCategoryColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final total = categoryTotals.values.fold(0.0, (acc, cur) => acc + cur);

    // Nếu không có dữ liệu, vẽ vòng tròn rỗng viền xám nhạt
    if (total <= 0) {
      final emptyPaint = Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20;
      canvas.drawCircle(center, radius - 10, emptyPaint);
      return;
    }

    double startAngle = -pi / 2; // Bắt đầu ở vị trí 12 giờ

    final defaultPalette = [
      Colors.deepOrange,
      Colors.blue,
      Colors.teal,
      Colors.purple,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
      Colors.indigo,
    ];
    int colorIndex = 0;

    for (final entry in categoryTotals.entries) {
      if (entry.value <= 0) continue;

      final sweepAngle = (entry.value / total) * 2 * pi;
      final paint = Paint()
        ..color = colors[entry.key] ?? defaultPalette[colorIndex % defaultPalette.length]
        ..style = PaintingStyle.fill;

      // Vẽ hình nan quạt (Arc)
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);

      startAngle += sweepAngle;
      colorIndex++;
    }

    // Khoét lỗ tròn ở tâm tạo hình bánh donut
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.55, innerPaint);
  }

  @override
  bool shouldRepaint(covariant PieChartPainter oldDelegate) {
    return oldDelegate.categoryTotals != categoryTotals;
  }
}

