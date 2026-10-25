import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../widgets/pie_chart_painter.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => ChartsScreenState();
}

class ChartsScreenState extends State<ChartsScreen> {
  List<String> _availableMonths = [];
  String? _selectedMonthYear;
  Map<String, double> _categoryTotals = {};
  double _monthTotal = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadChartData();
  }

  Future<void> loadChartData() async {
    setState(() => _isLoading = true);

    final months = await DatabaseHelper.instance.getAvailableMonths();
    final current = DateFormat('MM/yyyy').format(DateTime.now());

    String selected = _selectedMonthYear ?? (months.contains(current) ? current : months.first);
    if (!months.contains(selected) && months.isNotEmpty) {
      selected = months.first;
    }

    final parts = selected.split('/');
    final month = parts[0];
    final year = parts[1];

    final totals = await DatabaseHelper.instance.getTotalByCategoryForMonth(month, year);
    final sum = totals.values.fold(0.0, (acc, cur) => acc + cur);

    if (mounted) {
      setState(() {
        _availableMonths = months;
        _selectedMonthYear = selected;
        _categoryTotals = totals;
        _monthTotal = sum;
        _isLoading = false;
      });
    }
  }

  Future<void> _onMonthChanged(String? newMonthYear) async {
    if (newMonthYear == null || newMonthYear == _selectedMonthYear) return;

    final parts = newMonthYear.split('/');
    final month = parts[0];
    final year = parts[1];

    setState(() => _isLoading = true);
    final totals = await DatabaseHelper.instance.getTotalByCategoryForMonth(month, year);
    final sum = totals.values.fold(0.0, (acc, cur) => acc + cur);

    if (mounted) {
      setState(() {
        _selectedMonthYear = newMonthYear;
        _categoryTotals = totals;
        _monthTotal = sum;
        _isLoading = false;
      });
    }
  }

  String _formatVND(double amount) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return '${formatter.format(amount)} đ';
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant;
      case 'Study':
        return Icons.school;
      case 'Travel':
        return Icons.directions_car;
      case 'Gear':
        return Icons.devices;
      case 'Entertainment':
        return Icons.movie;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: loadChartData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thanh chọn Tháng/Năm
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt, color: Colors.deepPurple),
                    const SizedBox(width: 12),
                    const Text(
                      'Kỳ báo cáo:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const Spacer(),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedMonthYear,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.deepPurple),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                        items: _availableMonths.map((m) {
                          return DropdownMenuItem<String>(
                            value: m,
                            child: Text('Tháng $m'),
                          );
                        }).toList(),
                        onChanged: _onMonthChanged,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Card Biểu đồ hình tròn
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      'Phân Bổ Chi Tiêu ${_selectedMonthYear != null ? "Tháng $_selectedMonthYear" : ""}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tổng chi: ${_formatVND(_monthTotal)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Vẽ biểu đồ tròn bằng CustomPainter
                    Center(
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: CustomPaint(
                          painter: PieChartPainter(
                            categoryTotals: _categoryTotals,
                            colors: kCategoryColors,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_categoryTotals.isEmpty || _monthTotal <= 0)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: const Text(
                          'Không có dữ liệu chi tiêu trong tháng này',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Bảng chi tiết danh mục
            if (_categoryTotals.isNotEmpty && _monthTotal > 0) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chi Tiết Theo Danh Mục',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._categoryTotals.entries.map((entry) {
                        final cat = entry.key;
                        final amount = entry.value;
                        final percent = (amount / _monthTotal * 100);
                        final color = kCategoryColors[cat] ?? Colors.deepPurple;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: color.withValues(alpha: 0.15),
                                    child: Icon(_getCategoryIcon(cat), size: 16, color: color),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      cat,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${percent.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _formatVND(amount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percent / 100,
                                  backgroundColor: Colors.grey[200],
                                  color: color,
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

