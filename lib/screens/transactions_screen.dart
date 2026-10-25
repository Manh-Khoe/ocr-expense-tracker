import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../widgets/pie_chart_painter.dart';
import 'review_screen.dart';

class TransactionsScreen extends StatefulWidget {
  final VoidCallback? onDataChanged;

  const TransactionsScreen({super.key, this.onDataChanged});

  @override
  State<TransactionsScreen> createState() => TransactionsScreenState();
}

class TransactionsScreenState extends State<TransactionsScreen> {
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getExpenses();
    if (mounted) {
      setState(() {
        _expenses = data;
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

  /// Phân nhóm danh sách giao dịch theo Tháng/Năm
  Map<String, List<Map<String, dynamic>>> _groupExpensesByMonth() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final item in _expenses) {
      final dateStr = item['date'] as String? ?? '';
      String monthKey = 'Không xác định';

      final parts = dateStr.split(RegExp(r'[/-]'));
      if (parts.length == 3) {
        final m = parts[1].padLeft(2, '0');
        final y = parts[2].length == 2 ? '20${parts[2]}' : parts[2];
        monthKey = 'Tháng $m/$y';
      }

      grouped.putIfAbsent(monthKey, () => []).add(item);
    }

    return grouped;
  }

  Future<void> _deleteExpense(int id, String merchant) async {
    await DatabaseHelper.instance.deleteExpense(id);
    await loadTransactions();
    widget.onDataChanged?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa giao dịch "$merchant"'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showDetailBottomSheet(BuildContext context, Map<String, dynamic> item) {
    final merchant = item['merchant'] as String? ?? 'Cửa hàng';
    final amount = (item['total_amount'] as num?)?.toDouble() ?? 0.0;
    final date = item['date'] as String? ?? '';
    final category = item['category'] as String? ?? 'Khác';
    final note = item['note'] as String? ?? '';
    final imagePath = item['image_path'] as String?;
    final hasImage = imagePath != null && File(imagePath).existsSync();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    merchant,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _formatVND(amount),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Chip(
                  avatar: Icon(_getCategoryIcon(category), size: 16),
                  label: Text(category),
                  backgroundColor: (kCategoryColors[category] ?? Colors.purple)
                      .withValues(alpha: 0.15),
                ),
                const SizedBox(width: 8),
                Text(
                  'Ngày: $date',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (hasImage) ...[
              const SizedBox(height: 16),
              const Text(
                'Ảnh hóa đơn:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _editExpense(item);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Chỉnh sửa'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Đóng'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editExpense(Map<String, dynamic> item) async {
    final id = item['id'] as int;
    final merchant = item['merchant'] as String? ?? '';
    final amount = (item['total_amount'] as num?)?.toDouble() ?? 0.0;
    final date = item['date'] as String? ?? '';
    final category = item['category'] as String? ?? 'Food';
    final note = item['note'] as String? ?? '';
    final imagePath = item['image_path'] as String?;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewScreen(
          expenseId: id,
          initialMerchant: merchant,
          initialAmount: amount,
          initialDate: date,
          initialCategory: category,
          initialNote: note,
          imagePath: imagePath,
        ),
      ),
    );

    if (updated == true) {
      await loadTransactions();
      widget.onDataChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Chưa có giao dịch nào',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Quét hóa đơn OCR hoặc thêm thủ công để bắt đầu',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final grouped = _groupExpensesByMonth();

    return RefreshIndicator(
      onRefresh: loadTransactions,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80, top: 8),
        itemCount: grouped.keys.length,
        itemBuilder: (context, index) {
          final monthKey = grouped.keys.elementAt(index);
          final items = grouped[monthKey]!;
          final monthTotal = items.fold(
            0.0,
            (acc, cur) => acc + ((cur['total_amount'] as num?)?.toDouble() ?? 0.0),
          );

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header phân nhóm theo Tháng/Năm
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month,
                            size: 18,
                            color: Colors.deepPurple,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            monthKey,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${items.length} món',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatVND(monthTotal),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Danh sách item trong tháng
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (context, idx) => const Divider(height: 1, indent: 64),
                  itemBuilder: (context, itemIdx) {
                    final item = items[itemIdx];
                    final id = item['id'] as int;
                    final merchant = item['merchant'] as String? ?? 'Cửa hàng';
                    final amount = (item['total_amount'] as num?)?.toDouble() ?? 0.0;
                    final date = item['date'] as String? ?? '';
                    final category = item['category'] as String? ?? 'Khác';
                    final note = item['note'] as String? ?? '';
                    final color = kCategoryColors[category] ?? Colors.deepPurple;
                    final imagePath = item['image_path'] as String?;
                    final hasImage = imagePath != null && File(imagePath).existsSync();

                    return Dismissible(
                      key: ValueKey('trans_$id'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Xóa',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.delete, color: Colors.white),
                          ],
                        ),
                      ),
                      confirmDismiss: (dir) async {
                        return await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Xác nhận xóa'),
                            content: Text('Bạn có chắc muốn xóa giao dịch "$merchant"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Hủy'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'Xóa',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (_) => _deleteExpense(id, merchant),
                      child: ListTile(
                        onTap: () => _showDetailBottomSheet(context, item),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(_getCategoryIcon(category), color: color, size: 22),
                        ),
                        title: Text(
                          merchant,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$date • $category',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                            if (note.isNotEmpty)
                              Text(
                                note,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black54,
                                ),
                              ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatVND(amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                                fontSize: 14,
                              ),
                            ),
                            if (hasImage)
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.image, size: 12, color: Colors.teal),
                                    SizedBox(width: 2),
                                    Text(
                                      'Bill',
                                      style: TextStyle(fontSize: 10, color: Colors.teal),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

