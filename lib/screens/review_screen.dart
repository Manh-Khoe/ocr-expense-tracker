import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';

class ReviewScreen extends StatefulWidget {
  final int? expenseId; // Nếu có ID thì là chế độ Sửa, ngược lại là Thêm mới
  final String? initialMerchant;
  final double? initialAmount;
  final String? initialDate;
  final String? initialCategory;
  final String? initialNote;
  final String? imagePath;
  final String? rawText;

  const ReviewScreen({
    super.key,
    this.expenseId,
    this.initialMerchant,
    this.initialAmount,
    this.initialDate,
    this.initialCategory,
    this.initialNote,
    this.imagePath,
    this.rawText,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _merchantController;
  late TextEditingController _amountController;
  late TextEditingController _dateController;
  late TextEditingController _noteController;

  final List<String> _categories = [
    'Food',
    'Study',
    'Travel',
    'Gear',
    'Entertainment',
  ];

  late String _selectedCategory;
  String? _currentImagePath;
  bool _isSaving = false;

  bool get isEditMode => widget.expenseId != null;
  bool get isOcrMode => widget.imagePath != null && widget.imagePath!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _currentImagePath = widget.imagePath;

    _merchantController = TextEditingController(
      text: widget.initialMerchant ?? '',
    );

    final amt = widget.initialAmount;
    _amountController = TextEditingController(
      text: (amt != null && amt > 0) ? amt.toStringAsFixed(0) : '',
    );

    _dateController = TextEditingController(
      text: widget.initialDate ?? DateFormat('dd/MM/yyyy').format(DateTime.now()),
    );

    _noteController = TextEditingController(
      text: widget.initialNote ?? '',
    );

    if (widget.initialCategory != null && _categories.contains(widget.initialCategory)) {
      _selectedCategory = widget.initialCategory!;
    } else {
      _selectedCategory = _categories.first;
    }
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _noteController.dispose();
    super.dispose();
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

  Future<void> _selectDate() async {
    DateTime initial = DateTime.now();
    try {
      final parts = _dateController.text.split(RegExp(r'[/-]'));
      if (parts.length == 3) {
        initial = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file != null) {
      setState(() {
        _currentImagePath = file.path;
      });
    }
  }

  void _showImageDialog(BuildContext context, File file) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Ảnh Hóa Đơn'),
              elevation: 0,
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                  height: MediaQuery.of(context).size.height * 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final amountText = _amountController.text.replaceAll(RegExp(r'[^\d.]'), '');
    final totalAmount = double.tryParse(amountText) ?? 0.0;

    final data = {
      'merchant': _merchantController.text.trim().isEmpty
          ? 'Không có tên'
          : _merchantController.text.trim(),
      'total_amount': totalAmount,
      'date': _dateController.text.trim(),
      'category': _selectedCategory,
      'image_path': _currentImagePath,
      'note': _noteController.text.trim(),
    };

    try {
      if (isEditMode) {
        await DatabaseHelper.instance.updateExpense(widget.expenseId!, data);
      } else {
        await DatabaseHelper.instance.insertExpense(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditMode
                  ? 'Đã cập nhật giao dịch thành công!'
                  : 'Đã lưu giao dịch thành công!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _currentImagePath != null && File(_currentImagePath!).existsSync();
    final imageFile = hasImage ? File(_currentImagePath!) : null;

    final title = isEditMode
        ? 'Chỉnh Sửa Giao Dịch'
        : (isOcrMode ? 'Xác Nhận Hóa Đơn OCR' : 'Thêm Giao Dịch Thủ Công');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Khu vực hiển thị ảnh hóa đơn (nếu có) hoặc nút đính kèm ảnh
              if (hasImage && imageFile != null) ...[
                Card(
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                  child: Stack(
                    children: [
                      Container(
                        height: 180,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: Image.file(
                          imageFile,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.65),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _showImageDialog(context, imageFile),
                          icon: const Icon(Icons.zoom_in, size: 18),
                          label: const Text('Xem ảnh lớn'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                // Khi thêm thủ công: Cho phép chọn ảnh hóa đơn nếu muốn
                OutlinedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: Wrap(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.camera_alt),
                              title: const Text('Chụp ảnh từ Camera'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _pickImage(ImageSource.camera);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library),
                              title: const Text('Chọn ảnh từ Thư viện'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _pickImage(ImageSource.gallery);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Đính kèm ảnh hóa đơn (tùy chọn)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Card chứa các trường nhập liệu
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Tên cửa hàng / Đơn vị
                      TextFormField(
                        controller: _merchantController,
                        decoration: const InputDecoration(
                          labelText: 'Tên cửa hàng / Khoản chi',
                          prefixIcon: Icon(Icons.store),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập tên khoản chi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Số tiền
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tổng số tiền',
                          suffixText: 'VNĐ',
                          prefixIcon: Icon(Icons.payments_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập số tiền';
                          }
                          final parsed = double.tryParse(
                            value.replaceAll(RegExp(r'[^\d.]'), ''),
                          );
                          if (parsed == null || parsed <= 0) {
                            return 'Số tiền phải lớn hơn 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Ngày giao dịch
                      TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        onTap: _selectDate,
                        decoration: InputDecoration(
                          labelText: 'Ngày giao dịch (DD/MM/YYYY)',
                          prefixIcon: const Icon(Icons.calendar_today),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.edit_calendar),
                            onPressed: _selectDate,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Danh mục (Category)
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Danh mục chi tiêu',
                          prefixIcon: Icon(Icons.category_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: _categories.map((cat) {
                          return DropdownMenuItem<String>(
                            value: cat,
                            child: Row(
                              children: [
                                Icon(
                                  _getCategoryIcon(cat),
                                  color: Colors.deepPurple,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(cat),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCategory = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Ghi chú (Note)
                      TextFormField(
                        controller: _noteController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Ghi chú thêm (Note)',
                          prefixIcon: Icon(Icons.note_alt_outlined),
                          border: OutlineInputBorder(),
                          hintText: 'Ví dụ: Ăn trưa cùng đồng nghiệp...',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Nút Lưu / Cập nhật
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveExpense,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(isEditMode ? Icons.update : Icons.save),
                label: Text(
                  _isSaving
                      ? 'Đang lưu...'
                      : (isEditMode ? 'Cập Nhật Giao Dịch' : 'Lưu Giao Dịch'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
