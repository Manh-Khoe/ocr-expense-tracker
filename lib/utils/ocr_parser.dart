import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';

class OcrResult {
  final String merchant;
  final double amount;
  final String date;
  final String rawText;
  final String imagePath;

  OcrResult({
    required this.merchant,
    required this.amount,
    required this.date,
    required this.rawText,
    required this.imagePath,
  });
}

class OcrParser {
  /// Xử lý nhận diện OCR và bóc tách dữ liệu từ ảnh
  static Future<OcrResult> parseReceipt(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    RecognizedText recognizedText;
    try {
      recognizedText = await textRecognizer.processImage(inputImage);
    } finally {
      await textRecognizer.close();
    }

    final rawText = recognizedText.text;
    final merchant = extractMerchant(recognizedText);
    final amount = extractAmount(rawText);
    final date = extractDate(rawText);

    return OcrResult(
      merchant: merchant,
      amount: amount,
      date: date,
      rawText: rawText,
      imagePath: imagePath,
    );
  }

  /// Heuristic lấy tên cửa hàng:
  /// Lọc các dòng phía trên của hóa đơn, bỏ qua tiêu đề chung,
  /// ưu tiên dòng có kích thước font (chiều cao bounding box) lớn nhất hoặc dòng đầu tiên.
  static String extractMerchant(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) {
      return 'Cửa hàng';
    }

    // Tập hợp tất cả các dòng text kèm thông tin bounding box
    final List<TextLine> lines = [];
    for (final block in recognizedText.blocks) {
      lines.addAll(block.lines);
    }

    if (lines.isEmpty) {
      return 'Cửa hàng';
    }

    // Sắp xếp các dòng theo vị trí từ trên xuống dưới (top tăng dần)
    lines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    // Các từ khóa tiêu đề chung cần bỏ qua khi tìm tên cửa hàng
    final ignoreKeywords = [
      'hoa don',
      'hóa đơn',
      'receipt',
      'phieu thanh toan',
      'phiếu thanh toán',
      'bill',
      'tax invoice',
      'vat',
      'order',
      'ban hang',
      'bán hàng',
    ];

    // Chỉ xét các dòng trong nửa trên của hóa đơn (top 6 dòng đầu tiên)
    final candidateLines = lines.take(6).where((line) {
      final text = line.text.trim();
      if (text.length < 3) return false;

      // Bỏ qua nếu toàn số hoặc ký tự đặc biệt
      if (RegExp(r'^[\d\W]+$').hasMatch(text)) return false;

      final lower = text.toLowerCase();
      // Bỏ qua nếu chỉ chứa từ khóa hóa đơn chung
      for (final kw in ignoreKeywords) {
        if (lower == kw || lower == '$kw:' || lower.startsWith('$kw bán lẻ')) {
          return false;
        }
      }
      return true;
    }).toList();

    if (candidateLines.isEmpty) {
      // Fallback: lấy dòng text hợp lệ đầu tiên
      for (final line in lines) {
        final text = line.text.trim();
        if (text.length >= 3 && !RegExp(r'^[\d\W]+$').hasMatch(text)) {
          return text;
        }
      }
      return 'Cửa hàng';
    }

    // Heuristic: Tìm dòng có font lớn nhất (chiều cao boundingBox cao nhất)
    TextLine bestLine = candidateLines.first;
    double maxHeight = candidateLines.first.boundingBox.height;

    for (final candidate in candidateLines) {
      final h = candidate.boundingBox.height;
      if (h > maxHeight) {
        maxHeight = h;
        bestLine = candidate;
      }
    }

    return bestLine.text.trim();
  }

  /// Regex bóc tách số tiền VNĐ:
  /// Tìm các chuỗi có định dạng tiền tệ VNĐ (ví dụ: 125,000 đ, 50.000 VND,...)
  /// Ưu tiên lấy số tiền nằm cùng hoặc ngay sau dòng có từ khóa "Tổng cộng / Thành tiền / Total"
  static double extractAmount(String text) {
    if (text.isEmpty) return 0.0;

    final lines = text.split('\n');

    // 1. Kiểm tra dòng có từ khóa tổng tiền
    final totalKeywords = RegExp(
      r'(tổng\s*cộng|thanh\s*toán|thành\s*tiền|tong\s*cong|thanh\s*toan|thanh\s*tien|total|amount|phải\s*trả|cộng\s*tiền|grand\s*total)',
      caseSensitive: false,
    );

    // Regex tìm mẫu số tiền: VD 150.000, 150,000, 150000 kèm hoặc không kèm VND/đ/d
    final moneyPattern = RegExp(
      r'(\d{1,3}(?:[.,]\d{3})+(?:\s*(?:VND|VNĐ|vnd|vnđ|đ|d\b))?|\d{4,9}\s*(?:VND|VNĐ|vnd|vnđ|đ|d\b))',
      caseSensitive: false,
    );

    // Quét các dòng có từ khóa tổng trước
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (totalKeywords.hasMatch(line)) {
        // Tìm số tiền trong dòng hiện tại
        final match = moneyPattern.firstMatch(line);
        if (match != null) {
          final val = _parseAmountString(match.group(0)!);
          if (val > 0) return val;
        }
        // Hoặc kiểm tra dòng kế tiếp (thường nhãn 1 dòng, số 1 dòng)
        if (i + 1 < lines.length) {
          final nextMatch = moneyPattern.firstMatch(lines[i + 1]);
          if (nextMatch != null) {
            final val = _parseAmountString(nextMatch.group(0)!);
            if (val > 0) return val;
          }
        }
      }
    }

    // 2. Nếu không tìm thấy dòng từ khóa, quét toàn bộ văn bản tìm tất cả số tiền
    final allMatches = moneyPattern.allMatches(text);
    double maxAmount = 0.0;
    for (final m in allMatches) {
      final val = _parseAmountString(m.group(0)!);
      if (val > maxAmount) {
        maxAmount = val;
      }
    }

    return maxAmount;
  }

  /// Chuyển đổi chuỗi tiền tệ (VD: "150.000 VND", "125,000đ") thành double
  static double _parseAmountString(String raw) {
    // Xóa bỏ tất cả ký tự không phải số
    final clean = raw.replaceAll(RegExp(r'[^\d]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  /// Regex bóc tách ngày tháng:
  /// Tìm định dạng DD/MM/YYYY hoặc DD-MM-YYYY
  static String extractDate(String text) {
    if (text.isEmpty) {
      return DateFormat('dd/MM/yyyy').format(DateTime.now());
    }

    // Tìm dạng DD/MM/YYYY hoặc DD-MM-YYYY
    final dmyPattern = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b');
    final match = dmyPattern.firstMatch(text);
    if (match != null) {
      final d = match.group(1)!.padLeft(2, '0');
      final m = match.group(2)!.padLeft(2, '0');
      var y = match.group(3)!;
      if (y.length == 2) {
        y = '20$y';
      }
      return '$d/$m/$y';
    }

    // Tìm dạng Ngày DD tháng MM năm YYYY
    final vnPattern = RegExp(
      r'(?:ngày|ngay)\s*(\d{1,2})\s*(?:tháng|thang)\s*(\d{1,2})\s*(?:năm|nam)\s*(\d{4})',
      caseSensitive: false,
    );
    final vnMatch = vnPattern.firstMatch(text);
    if (vnMatch != null) {
      final d = vnMatch.group(1)!.padLeft(2, '0');
      final m = vnMatch.group(2)!.padLeft(2, '0');
      final y = vnMatch.group(3)!;
      return '$d/$m/$y';
    }

    // Mặc định trả về ngày hôm nay nếu không nhận diện được
    return DateFormat('dd/MM/yyyy').format(DateTime.now());
  }
}

