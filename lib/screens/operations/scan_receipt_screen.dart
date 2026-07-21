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

    _parsedStore = _findStoreName(lines);
    _parsedDate = _findDate(lines);
    _parsedAmount = _findAmount(lines);

    _amountCtrl.text = _parsedAmount;
    _dateCtrl.text = _parsedDate;
    _commentCtrl.text = _parsedStore.isNotEmpty ? 'Чек: $_parsedStore' : '';
  }

  String _normalize(String s) {
    return s
        .replaceAll('M', 'м').replaceAll('T', 'т').replaceAll('O', 'о')
        .replaceAll('P', 'п').replaceAll('C', 'с').replaceAll('B', 'в')
        .replaceAll('A', 'а').replaceAll('E', 'е').replaceAll('K', 'к')
        .replaceAll('X', 'х').replaceAll('H', 'н').replaceAll('I', 'и')
        .replaceAll('p', 'р').replaceAll('a', 'а').replaceAll('e', 'е')
        .replaceAll('c', 'с').replaceAll('m', 'м').replaceAll('o', 'о')
        .replaceAll('i', 'и').replaceAll('y', 'у').toLowerCase();
  }

  String _findStoreName(List<String> lines) {
    final skipWords = ['эклз', 'инн', 'ккт', 'рн ккт', 'фд', 'фп', 'зн ккт', 'зн кт',
      'кассовый', 'чека', 'чеком', 'ип', 'ооо', 'сайт', 'тел', 'адрес',
      'огрн', 'эл', 'система', 'меркурий', 'штрих', 'атол', 'эвотор',
      'рисунок', 'untitled', 'figma', 'telegram', 'explorer',
      'каталог', 'catalog', 'easyfinance', 'яндекс', 'картинк'];

    final storeClues = ['ресторан', 'магазин', 'кафе', 'бар', 'столовая',
      'кальянная', 'кофейн', 'пиццер'];

    for (final line in lines) {
      final lower = line.toLowerCase();
      final norm = _normalize(line);
      if (lower.length < 5) continue;
      if (skipWords.any((w) => lower.contains(w) || norm.contains(w))) continue;
      if (storeClues.any((c) => norm.contains(c))) return line;
    }
    for (final line in lines) {
      final lower = line.toLowerCase();
      final norm = _normalize(line);
      if (lower.length < 5) continue;
      if (skipWords.any((w) => lower.contains(w) || norm.contains(w))) continue;
      if (RegExp(r'[а-яё]{4,}').hasMatch(norm)) return line;
    }
    return lines.isNotEmpty ? lines.first : '';
  }

  String _findDate(List<String> lines) {
    final dateRegex = RegExp(r'(\d{2})[./](\d{2})[./](\d{2,4})');
    for (final line in lines) {
      final m = dateRegex.firstMatch(line);
      if (m != null) {
        final d = int.tryParse(m.group(1) ?? '') ?? 0;
        final mo = int.tryParse(m.group(2) ?? '') ?? 0;
        var y = int.tryParse(m.group(3) ?? '') ?? 0;
        if (d < 1 || d > 31 || mo < 1 || mo > 12) continue;
        if (y < 100) y += 2000;
        if (y < 2000 || y > 2100) continue;
        return '${y.toString().padLeft(4, '0')}-${mo.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      }
    }
    return '';
  }

  String _findAmount(List<String> lines) {
    for (int i = lines.length - 1; i >= 0; i--) {
      final norm = _normalize(lines[i]);
      if (['итог', 'сумма', 'к оплате', 'всего'].any((k) => norm.contains(k))) {
        var nums = _extractSignificantNumbers(lines[i]);
        if (nums.isEmpty && i + 1 < lines.length) nums = _extractSignificantNumbers(lines[i + 1]);
        if (nums.isNotEmpty) return nums.last.toStringAsFixed(0);
      }
    }
    final eqValues = <double, int>{};
    for (final line in lines) {
      if (line.contains('=')) {
        final nums = _extractSignificantNumbers(line);
        for (final n in nums) {
          eqValues[n] = (eqValues[n] ?? 0) + 1;
        }
      }
    }
    if (eqValues.isNotEmpty) {
      double best = 0;
      int bestCount = 0;
      eqValues.forEach((val, count) {
        if (count > bestCount) { best = val; bestCount = count; }
      });
      if (best > 0) return best.toStringAsFixed(0);
    }
    final allNums = <double>[];
    for (final line in lines) {
      allNums.addAll(_extractSignificantNumbers(line));
    }
    if (allNums.isNotEmpty) {
      allNums.sort();
      return allNums.last.toStringAsFixed(0);
    }
    return '';
  }

  List<double> _extractSignificantNumbers(String s) {
    final parts = s.split(RegExp(r'[^\d.,]+')).where((p) => p.isNotEmpty).toList();
    final result = <double>[];
    for (final p in parts) {
      final v = double.tryParse(p.replaceAll(',', '.'));
      if (v != null && v > 10) result.add(v);
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
