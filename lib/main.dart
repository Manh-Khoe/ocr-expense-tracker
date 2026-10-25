import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'database_helper.dart';
import 'screens/charts_screen.dart';
import 'screens/review_screen.dart';
import 'screens/transactions_screen.dart';
import 'utils/ocr_parser.dart';
import 'widgets/pie_chart_painter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartExpenseApp());
}

class SmartExpenseApp extends StatelessWidget {
  const SmartExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Expense OCR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const MainNavigationScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final ImagePicker _picker = ImagePicker();

  final GlobalKey<TransactionsScreenState> _transactionsKey = GlobalKey();
  final GlobalKey<ChartsScreenState> _chartsKey = GlobalKey();

  // Dữ liệu cho tab Dashboard
  List<Map<String, dynamic>> _recentExpenses = [];
  Map<String, double> _currentMonthCategoryTotals = {};
  double _currentMonthTotal = 0.0;
  int _currentMonthCount = 0;
  bool _isLoadingDashboard = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  /// Tải dữ liệu cho Dashboard
  Future<void> _loadDashboardData() async {
    setState(() => _isLoadingDashboard = true);

    final now = DateTime.now();
    final month = now.month.toString();
    final year = now.year.toString();

    final monthExpenses = await DatabaseHelper.instance.getExpensesByMonth(month, year);
    final monthTotals = await DatabaseHelper.instance.getTotalByCategoryForMonth(month, year);
    final allExpenses = await DatabaseHelper.instance.getExpenses();

    final sum = monthTotals.values.fold(0.0, (acc, cur) => acc + cur);

    if (mounted) {
      setState(() {
        _recentExpenses = allExpenses.take(5).toList();
        _currentMonthCategoryTotals = monthTotals;
        _currentMonthTotal = sum;
        _currentMonthCount = monthExpenses.length;
        _isLoadingDashboard = false;
      });
    }
  }

  /// Làm mới toàn bộ dữ liệu trên các tab
  void _refreshAllTabs() {
    _loadDashboardData();
    _transactionsKey.currentState?.loadTransactions();
    _chartsKey.currentState?.loadChartData();
  }

  /// Chụp ảnh hoặc chọn ảnh từ thư viện để OCR
  Future<void> _startOcrScan(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (photo == null) return;
      if (!mounted) return;

      // Hiển thị Dialog đang nhận diện OCR
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Expanded(
                  child: Text('Đang phân tích OCR hóa đơn...'),
                ),
              ],
            ),
          ),
        ),
      );

      // Phân tích OCR
      final ocrResult = await OcrParser.parseReceipt(photo.path);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Đóng loading dialog

      // Mở Màn hình Review với dữ liệu trích xuất
      final isSaved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => ReviewScreen(
            initialMerchant: ocrResult.merchant,
            initialAmount: ocrResult.amount,
            initialDate: ocrResult.date,
            imagePath: ocrResult.imagePath,
            rawText: ocrResult.rawText,
          ),
        ),
      );

      if (isSaved == true) {
        _refreshAllTabs();
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi quét hóa đơn: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Mở màn hình Thêm giao dịch thủ công (không có ảnh hoặc tự đính kèm)
  Future<void> _openManualAdd() async {
    final isSaved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const ReviewScreen(),
      ),
    );

    if (isSaved == true) {
      _refreshAllTabs();
    }
  }

  /// Menu hành động chọn cách thêm giao dịch
  void _showAddActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Chọn Phương Thức Nhập',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  child: Icon(Icons.camera_alt, color: Colors.white),
                ),
                title: const Text('Chụp Hóa Đơn (OCR)'),
                subtitle: const Text('Tự động bóc tách tên quán, số tiền, ngày'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startOcrScan(ImageSource.camera);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.shade700,
                  child: const Icon(Icons.photo_library, color: Colors.white),
                ),
                title: const Text('Quét Hóa Đơn từ Thư Viện'),
                subtitle: const Text('Chọn ảnh bill có sẵn trong máy'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startOcrScan(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade800,
                  child: const Icon(Icons.edit_note, color: Colors.white),
                ),
                title: const Text('Thêm Giao Dịch Thủ Công'),
                subtitle: const Text('Tự nhập thông tin chi tiêu bằng tay'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openManualAdd();
                },
              ),
            ],
          ),
        ),
      ),
    );
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

  /// Giao diện Tab Home (Tổng quan / Dashboard)
  Widget _buildHomeTab() {
    if (_isLoadingDashboard) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();
    final currentMonthLabel = DateFormat('MM/yyyy').format(now);

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thẻ Tổng quan chi tiêu tháng này
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.deepPurple, Colors.indigo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(22.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Chi tiêu Tháng $currentMonthLabel',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_currentMonthCount hóa đơn',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatVND(_currentMonthTotal),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Các nút hành động nhanh (Quick Actions)
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.camera_alt,
                    label: 'Quét OCR',
                    color: Colors.deepPurple,
                    onTap: () => _startOcrScan(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.photo_library,
                    label: 'Thư viện',
                    color: Colors.teal,
                    onTap: () => _startOcrScan(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.add_circle_outline,
                    label: 'Thủ công',
                    color: Colors.orange.shade800,
                    onTap: _openManualAdd,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // Mini Biểu đồ tròn phân bổ tháng này
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Phân Bổ Tháng Này',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _currentIndex = 2),
                          child: const Text('Xem biểu đồ đầy đủ'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_currentMonthTotal > 0) ...[
                      Center(
                        child: SizedBox(
                          width: 150,
                          height: 150,
                          child: CustomPaint(
                            painter: PieChartPainter(
                              categoryTotals: _currentMonthCategoryTotals,
                              colors: kCategoryColors,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: _currentMonthCategoryTotals.entries.map((e) {
                          final color = kCategoryColors[e.key] ?? Colors.grey;
                          final pct = (e.value / _currentMonthTotal * 100).toStringAsFixed(0);
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${e.key} ($pct%)',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Chưa có giao dịch trong tháng này',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            // Giao dịch gần đây (Recent Transactions)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Giao Dịch Gần Đây',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _currentIndex = 1),
                  child: const Text('Xem tất cả'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_recentExpenses.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: const Center(
                  child: Text(
                    'Chưa có giao dịch nào được lưu',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentExpenses.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _recentExpenses[index];
                  final merchant = item['merchant'] as String? ?? 'Cửa hàng';
                  final amount = (item['total_amount'] as num?)?.toDouble() ?? 0.0;
                  final date = item['date'] as String? ?? '';
                  final category = item['category'] as String? ?? 'Khác';
                  final note = item['note'] as String? ?? '';
                  final color = kCategoryColors[category] ?? Colors.deepPurple;
                  final hasImage = item['image_path'] != null &&
                      File(item['image_path'] as String).existsSync();

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(_getCategoryIcon(category), color: color, size: 20),
                    ),
                    title: Text(
                      merchant,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      note.isNotEmpty ? '$date • $category\n$note' : '$date • $category',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatVND(amount),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (hasImage)
                          const Text(
                            '📷 Bill',
                            style: TextStyle(fontSize: 10, color: Colors.teal),
                          ),
                      ],
                    ),
                    onTap: () {
                      setState(() => _currentIndex = 1);
                    },
                  );
                },
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text(
              'Smart Expense OCR',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _refreshAllTabs,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          TransactionsScreen(
            key: _transactionsKey,
            onDataChanged: _refreshAllTabs,
          ),
          ChartsScreen(
            key: _chartsKey,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          setState(() => _currentIndex = idx);
          if (idx == 0) _loadDashboardData();
          if (idx == 1) _transactionsKey.currentState?.loadTransactions();
          if (idx == 2) _chartsKey.currentState?.loadChartData();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Colors.deepPurple),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: Colors.deepPurple),
            label: 'Giao dịch',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart, color: Colors.deepPurple),
            label: 'Biểu đồ',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddActionSheet,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Thêm / Quét'),
      ),
    );
  }
}
