import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expenses.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant TEXT NOT NULL,
        total_amount REAL NOT NULL,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        image_path TEXT,
        note TEXT
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Bổ sung cột note khi nâng cấp từ v1 lên v2
      try {
        await db.execute('ALTER TABLE expenses ADD COLUMN note TEXT;');
      } catch (_) {
        // Cột có thể đã tồn tại nếu trước đó đã tạo
      }
    }
  }

  /// Thêm giao dịch mới
  Future<int> insertExpense(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('expenses', row);
  }

  /// Cập nhật giao dịch
  Future<int> updateExpense(int id, Map<String, dynamic> row) async {
    final db = await database;
    return await db.update(
      'expenses',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Xóa giao dịch theo ID
  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Lấy toàn bộ danh sách giao dịch
  Future<List<Map<String, dynamic>>> getExpenses() async {
    final db = await database;
    return await db.query(
      'expenses',
      orderBy: 'id DESC',
    );
  }

  /// Lấy chi tiết một giao dịch
  Future<Map<String, dynamic>?> getExpenseById(int id) async {
    final db = await database;
    final res = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (res.isNotEmpty) return res.first;
    return null;
  }

  /// Lọc danh sách giao dịch theo tháng và năm
  /// month: "10" hoặc "01" đến "12"
  /// year: "2026"
  Future<List<Map<String, dynamic>>> getExpensesByMonth(
    String month,
    String year,
  ) async {
    final db = await database;
    final m = month.padLeft(2, '0');
    final slashPattern = '%/$m/$year';
    final dashPattern = '%-$m-$year';

    return await db.query(
      'expenses',
      where: 'date LIKE ? OR date LIKE ?',
      whereArgs: [slashPattern, dashPattern],
      orderBy: 'id DESC',
    );
  }

  /// Lấy tổng chi tiêu theo từng category (tất cả thời gian)
  Future<Map<String, double>> getTotalByCategory() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT category, SUM(total_amount) as total
      FROM expenses
      GROUP BY category
    ''');

    final Map<String, double> totals = {};
    for (final row in result) {
      final category = row['category'] as String?;
      final total = row['total'];
      if (category != null && total != null) {
        totals[category] = (total as num).toDouble();
      }
    }
    return totals;
  }

  /// Tổng hợp dữ liệu biểu đồ theo Tháng/Năm
  Future<Map<String, double>> getTotalByCategoryForMonth(
    String month,
    String year,
  ) async {
    final db = await database;
    final m = month.padLeft(2, '0');
    final slashPattern = '%/$m/$year';
    final dashPattern = '%-$m-$year';

    final result = await db.rawQuery('''
      SELECT category, SUM(total_amount) as total
      FROM expenses
      WHERE date LIKE ? OR date LIKE ?
      GROUP BY category
    ''', [slashPattern, dashPattern]);

    final Map<String, double> totals = {};
    for (final row in result) {
      final category = row['category'] as String?;
      final total = row['total'];
      if (category != null && total != null) {
        totals[category] = (total as num).toDouble();
      }
    }
    return totals;
  }

  /// Lấy danh sách các Tháng/Năm có dữ liệu giao dịch trong DB
  /// Kết quả dạng ['10/2026', '09/2026', ...]
  Future<List<String>> getAvailableMonths() async {
    final db = await database;
    final result = await db.rawQuery('SELECT DISTINCT date FROM expenses');
    final Set<String> months = {};

    for (final row in result) {
      final d = row['date'] as String?;
      if (d != null) {
        final parts = d.split(RegExp(r'[/-]'));
        if (parts.length == 3) {
          final m = parts[1].padLeft(2, '0');
          final y = parts[2].length == 2 ? '20${parts[2]}' : parts[2];
          months.add('$m/$y');
        }
      }
    }

    final currentMonth = DateFormat('MM/yyyy').format(DateTime.now());
    months.add(currentMonth);

    final list = months.toList();
    // Sắp xếp giảm dần theo năm rồi tháng
    list.sort((a, b) {
      final aParts = a.split('/');
      final bParts = b.split('/');
      final aVal = int.parse(aParts[1]) * 100 + int.parse(aParts[0]);
      final bVal = int.parse(bParts[1]) * 100 + int.parse(bParts[0]);
      return bVal.compareTo(aVal);
    });

    return list;
  }

  /// Đóng kết nối
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}
