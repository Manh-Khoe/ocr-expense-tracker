import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_expense_tracker/utils/ocr_parser.dart';

void main() {
  group('OcrParser Regex & Heuristics Tests', () {
    test('extractAmount extracts correct VND amount from lines with keywords', () {
      const receiptText = '''
        SIÊU THỊ BÁCH HÓA XANH
        Đ/c: 123 Nguyễn Văn Cừ
        Mặt hàng A: 25.000 đ
        Mặt hàng B: 50.000 đ
        Tổng cộng: 75.000 VND
        Cảm ơn quý khách!
      ''';

      final amount = OcrParser.extractAmount(receiptText);
      expect(amount, 75000.0);
    });

    test('extractAmount extracts maximum amount when no total keyword exists', () {
      const receiptText = '''
        Cà phê sữa đá 35,000đ
        Trà đào 45,000đ
      ''';

      final amount = OcrParser.extractAmount(receiptText);
      expect(amount, 45000.0);
    });

    test('extractDate extracts DD/MM/YYYY format correctly', () {
      const receiptText = '''
        HÓA ĐƠN BÁN LẺ
        Ngày: 25/10/2026
        Số tiền: 120.000 đ
      ''';

      final date = OcrParser.extractDate(receiptText);
      expect(date, '25/10/2026');
    });

    test('extractDate extracts Vietnamese date format correctly', () {
      const receiptText = '''
        HÓA ĐƠN
        Ngày 15 tháng 08 năm 2026
        Tổng tiền: 200.000 đ
      ''';

      final date = OcrParser.extractDate(receiptText);
      expect(date, '15/08/2026');
    });
  });
}
