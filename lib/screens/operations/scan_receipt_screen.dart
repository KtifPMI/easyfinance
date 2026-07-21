import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../store/finance_store.dart';
import '../../models/operation.dart';
import '../../theme/theme.dart';
import '../../components/common/screen_scaffold.dart';

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  File? _image;
  bool _scanning = false;
  String? _recognizedText;
  String? _error;
  bool _showConfirm = false;

  String _parsedAmount = '';
  String _parsedStore = '';
  String _parsedDate = '';
  final _commentCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();

  final _picker = ImagePicker();
  final _textRecognizer = TextRecognizer();

  @override
  void dispose() {
    _textRecognizer.close();
    _commentCtrl.dispose();
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 2048);
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      _image = File(picked.path);
      _scanning = true;
      _error = null;
      _recognizedText = null;
      _showConfirm = false;
    });
    await _scanReceipt();
  }

  Future<void> _scanReceipt() async {
    if (_image == null) return;
    try {
      final inputImage = InputImage.fromFile(_image!);
      final result = await _textRecognizer.processImage(inputImage);
      if (!mounted) return;
      final text = result.text;
      if (text.isEmpty) {
        setState(() { _error = 'Не удалось распознать текст. Попробуйте другое фото.'; _scanning = false; });
        return;
      }
      _parseReceiptText(text);
      setState(() {
        _recognizedText = text;
        _scanning = false;
        _showConfirm = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Ошибка распознавания: $e'; _scanning = false; });
    }
  }

  void _parseReceiptText(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final store = lines.isNotEmpty ? lines.first : '';
    _parsedStore = store;

    final dateRegex = RegExp(r'(\d{2})[./](\d{2})[./](\d{2,4})');
    for (final line in lines) {
      final m = dateRegex.firstMatch(line);
      if (m != null) {
        _parsedDate = '${m.group(3)!.padLeft(4, '20')}-${m.group(2)}-${m.group(1)}';
        break;
      }
    }

    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i].toLowerCase();
      if (['итог', 'сумма', 'к оплате', 'всего', 'cash', 'change', 'нал'].any((k) => line.contains(k))) {
        final nums = _extractNumbers(lines[i]);
        if (nums.isNotEmpty) { _parsedAmount = nums.last.toStringAsFixed(0); break; }
      }
    }
    if (_parsedAmount.isEmpty) {
      for (int i = lines.length - 1; i >= 0; i--) {
        final nums = _extractNumbers(lines[i]);
        if (nums.isNotEmpty) { _parsedAmount = nums.last.toStringAsFixed(0); break; }
      }
    }
    _amountCtrl.text = _parsedAmount;
    _dateCtrl.text = _parsedDate;
    _commentCtrl.text = 'Чек: $_parsedStore';
  }

  List<double> _extractNumbers(String s) {
    final parts = s.split(RegExp(r'[^\d.,]+')).where((p) => p.isNotEmpty).toList();
    final result = <double>[];
    for (final p in parts) {
      final v = double.tryParse(p.replaceAll(',', '.'));
      if (v != null && v > 0) result.add(v);
    }
    return result;
  }

  Future<void> _save(FinanceStore store) async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) return;
    if (store.accounts.isEmpty) return;

    final catId = store.categories.where((c) => c.type == 'expense').firstOrNull?.id;
    final now = DateTime.now();
    final dateStr = _dateCtrl.text.isNotEmpty
        ? '${_dateCtrl.text}T${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}'
        : now.toIso8601String();

    final op = Operation(
      id: now.microsecondsSinceEpoch.toRadixString(36),
      type: 'expense',
      amount: amount,
      date: dateStr,
      accountId: store.accounts.first.id,
      categoryId: catId,
      comment: _commentCtrl.text.isNotEmpty ? _commentCtrl.text : 'Чек: $_parsedStore',
    );

    await store.addOperation(op);
    if (!mounted) return;
    if (store.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(store.error!), backgroundColor: Colors.red),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Расход добавлен: $amount ₽'), backgroundColor: AppColors.success),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        return ScreenScaffold(
          title: 'Сканировать чек',
          child: _buildBody(store),
        );
      },
    );
  }

  Widget _buildBody(FinanceStore store) {
    if (_showConfirm && _image != null) {
      return _buildConfirmSection(store);
    }
    return Column(
      children: [
        if (_image != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(_image!, height: 300, width: double.infinity, fit: BoxFit.contain),
          ),
          const SizedBox(height: 16),
        ],
        if (_scanning) ...[
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 12),
          Text('Распознавание...', style: TextStyle(color: AppColors.textSecondaryFor(context))),
        ],
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.expense.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(_error!, style: TextStyle(color: AppColors.expense, fontSize: 14)),
          ),
          const SizedBox(height: 16),
        ],
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt, size: 20),
                label: const Text('Камера'),
                onPressed: () => _pickImage(ImageSource.camera),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.photo_library, size: 20),
                label: const Text('Галерея'),
                onPressed: () => _pickImage(ImageSource.gallery),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildConfirmSection(FinanceStore store) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_image != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_image!, height: 200, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
          ],
          if (_recognizedText != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardFor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderFor(context)),
              ),
              child: Text(_recognizedText!, style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
            ),
            const SizedBox(height: 16),
          ],
          Text('Магазин', style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
          const SizedBox(height: 4),
          Text(_parsedStore, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
          const SizedBox(height: 16),
          Text('Сумма расхода', style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
          const SizedBox(height: 4),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              filled: true, fillColor: AppColors.cardFor(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textFor(context)),
          ),
          const SizedBox(height: 16),
          Text('Дата', style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
          const SizedBox(height: 4),
          TextField(
            controller: _dateCtrl,
            decoration: InputDecoration(
              filled: true, fillColor: AppColors.cardFor(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            style: TextStyle(fontSize: 15, color: AppColors.textFor(context)),
          ),
          const SizedBox(height: 16),
          Text('Комментарий', style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
          const SizedBox(height: 4),
          TextField(
            controller: _commentCtrl,
            decoration: InputDecoration(
              filled: true, fillColor: AppColors.cardFor(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            style: TextStyle(fontSize: 15, color: AppColors.textFor(context)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _save(store),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Добавить расход', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => setState(() => _showConfirm = false),
              child: Text('Назад', style: TextStyle(color: AppColors.textSecondaryFor(context))),
            ),
          ),
        ],
      ),
    );
  }
}
