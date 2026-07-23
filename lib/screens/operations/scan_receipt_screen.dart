import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
  String? _selectedAccountId;
  String? _selectedCategoryId;
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

  Future<void> _pickImage(ImageSource source, FinanceStore store) async {
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
    await _scanReceipt(store);
  }

  Future<void> _scanReceipt(FinanceStore store) async {
    if (_image == null) return;
    try {
      final inputImage = InputImage.fromFile(_image!);
      final result = await _textRecognizer.processImage(inputImage);
      if (!mounted) return;
      final text = result.text;
      if (text.isEmpty) {
        setState(() { _error = context.tr('scan.error_recognize'); _scanning = false; });
        return;
      }
      _parseReceiptText(text, store);
      setState(() {
        _recognizedText = text;
        _scanning = false;
        _showConfirm = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = context.tr('scan.error_format', namedArgs: {'error': '$e'}); _scanning = false; });
    }
  }

  void _parseReceiptText(String text, FinanceStore store) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final normAll = _normalize(text);

    _parsedStore = _findStoreName(lines);
    _parsedDate = _findDate(lines);
    _parsedAmount = _findAmount(lines);

    _selectedCategoryId = _detectCategory(normAll, store.categories);
    _selectedCategoryId ??= store.categories.where((c) => c.type == 'expense').firstOrNull?.id;
    _selectedAccountId ??= store.accounts.isNotEmpty ? store.accounts.first.id : null;

    _amountCtrl.text = _parsedAmount;
    _dateCtrl.text = _parsedDate;
    _commentCtrl.text = _normalizeDisplay(_parsedStore);
  }

  String _normalize(String s) {
    return s
        .replaceAll('A', 'а').replaceAll('a', 'а')
        .replaceAll('B', 'в').replaceAll('b', 'в')
        .replaceAll('C', 'с').replaceAll('c', 'с')
        .replaceAll('E', 'е').replaceAll('e', 'е')
        .replaceAll('H', 'н').replaceAll('h', 'н')
        .replaceAll('I', 'и').replaceAll('i', 'и')
        .replaceAll('K', 'к').replaceAll('k', 'к')
        .replaceAll('M', 'м').replaceAll('m', 'м')
        .replaceAll('O', 'о').replaceAll('o', 'о')
        .replaceAll('P', 'р').replaceAll('p', 'р')
        .replaceAll('R', 'г').replaceAll('r', 'г')
        .replaceAll('T', 'т').replaceAll('t', 'т')
        .replaceAll('U', 'и').replaceAll('u', 'и')
        .replaceAll('X', 'х').replaceAll('x', 'х')
        .replaceAll('Y', 'у').replaceAll('y', 'у')
        .toLowerCase();
  }

  String _normalizeDisplay(String s) {
    return s
        .replaceAll('A', 'А').replaceAll('a', 'а')
        .replaceAll('B', 'В').replaceAll('b', 'в')
        .replaceAll('C', 'С').replaceAll('c', 'с')
        .replaceAll('D', 'Д').replaceAll('d', 'д')
        .replaceAll('E', 'Е').replaceAll('e', 'е')
        .replaceAll('H', 'Н').replaceAll('h', 'н')
        .replaceAll('I', 'И').replaceAll('i', 'и')
        .replaceAll('K', 'К').replaceAll('k', 'к')
        .replaceAll('M', 'М').replaceAll('m', 'м')
        .replaceAll('N', 'Л').replaceAll('n', 'л')
        .replaceAll('O', 'О').replaceAll('o', 'о')
        .replaceAll('P', 'Р').replaceAll('p', 'р')
        .replaceAll('R', 'Г').replaceAll('r', 'г')
        .replaceAll('T', 'Т').replaceAll('t', 'т')
        .replaceAll('U', 'И').replaceAll('u', 'и')
        .replaceAll('X', 'Х').replaceAll('x', 'х')
        .replaceAll('Y', 'У').replaceAll('y', 'у')
        .replaceAll('3', 'з').replaceAll('0', 'о')
        .replaceAll('6', 'б');
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

  String? _detectCategory(String normalizedText, List<dynamic> categories) {
    final categoryClues = {
      'питание': ['ресторан', 'кафе', 'столовая', 'бар', 'кофейн', 'пиццер', 'еда', 'продукт', 'блюдо', 'порци', 'вино', 'пиво', 'кофе', 'чай', 'мясо', 'рыба', 'салат', 'суп', 'хлеб', 'молоко', 'сыр', 'колбас', 'напиток', 'сок', 'десерт', 'пицца', 'ролл', 'суши', 'бургер', 'картоф', 'свинин', 'курица', 'котлет', 'пельмен', 'блины', 'морожен', 'шоколад', 'торт', 'пирожн', 'бутерброд', 'азу', 'паста', 'макарон', 'масло', 'творог', 'яиц', 'говядин', 'лосось', 'креветк', 'кальмар'],
      'автомобиль': ['авто', 'заправк', 'аэро', 'азс', 'шиномонтаж', 'сто', 'бензин', 'дизел', 'топлив', 'аи-95', 'аи-92'],
      'досуг и отдых': ['кино', 'театр', 'концерт', 'парк', 'развлек', 'билет'],
      'домашнее хозяйство': ['магазин', 'хоз', 'стройматер', 'мебель', 'обои', 'краск', 'ламинат'],
      'проезд, транспорт': ['такси', 'метро', 'автобус', 'транспорт', 'билет'],
      'одежда, обувь, аксессуары': ['одежд', 'обувь', 'аксессуар', 'футболк', 'штан', 'куртк', 'джинс', 'шапк'],
      'медицина': ['лекарств', 'таблетк', 'аптеч', 'капел', 'микстур', 'пластыр', 'витамин', 'антибиотик'],
    };
    for (final entry in categoryClues.entries) {
      if (entry.value.any((c) => normalizedText.contains(c))) {
        for (final cat in categories) {
          if (cat.name.toLowerCase().contains(entry.key)) {
            return cat.id;
          }
        }
      }
    }
    return null;
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
      final raw = lines[i].toLowerCase();
      if (['итог', 'сумма', 'к оплате', 'всего'].any((k) => norm.contains(k)) ||
          raw.contains('mtor') || raw.contains('cymma') || raw.contains('k onlate')) {
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
        if (count > bestCount || (count == bestCount && val > best)) {
          best = val;
          bestCount = count;
        }
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
      final cleaned = p.replaceAll(',', '.').replaceAll('О', '0').replaceAll('о', '0');
      final v = double.tryParse(cleaned);
      if (v != null && v > 10) result.add(v);
    }
    return result;
  }

  Future<void> _save(FinanceStore store) async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) return;
    if (store.accounts.isEmpty) return;

    final catId = _selectedCategoryId ?? store.categories.where((c) => c.type == 'expense').firstOrNull?.id;
    final now = DateTime.now();
    final dateStr = _dateCtrl.text.isNotEmpty
        ? '${_dateCtrl.text}T${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}'
        : now.toIso8601String();

    final op = Operation(
      id: now.microsecondsSinceEpoch.toRadixString(36),
      type: 'expense',
      amount: amount,
      date: dateStr,
      accountId: _selectedAccountId ?? store.accounts.first.id,
      categoryId: catId,
      comment: _commentCtrl.text.isNotEmpty ? _commentCtrl.text : context.tr('scan.receipt_comment', namedArgs: {'store': _parsedStore}),
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
      SnackBar(content: Text(context.tr('scan.expense_added', namedArgs: {'amount': amount.toStringAsFixed(0)})), backgroundColor: AppColors.success),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        return ScreenScaffold(
          title: context.tr('scan.title'),
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
          Text(context.tr('scan.recognizing'), style: TextStyle(color: AppColors.textSecondaryFor(context))),
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
                label: Text(context.tr('scan.camera')),
                onPressed: () => _pickImage(ImageSource.camera, store),
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
                label: Text(context.tr('scan.gallery')),
                onPressed: () => _pickImage(ImageSource.gallery, store),
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
          Text(context.tr('scan.account'), style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedAccountId,
            decoration: InputDecoration(
              filled: true, fillColor: AppColors.cardFor(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: store.accounts.map((a) => DropdownMenuItem<String>(value: a.id, child: Text(a.name))).toList(),
            onChanged: (v) => setState(() => _selectedAccountId = v),
          ),
          const SizedBox(height: 16),
          Text(context.tr('scan.category'), style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategoryId,
            decoration: InputDecoration(
              filled: true, fillColor: AppColors.cardFor(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: store.categories.where((c) => c.type == 'expense').map((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name))).toList(),
            onChanged: (v) => setState(() => _selectedCategoryId = v),
          ),
          const SizedBox(height: 16),
          Text(context.tr('scan.amount'), style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
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
          Text(context.tr('scan.date'), style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
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
          Text(context.tr('scan.comment'), style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
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
              child: Text(context.tr('scan.add_expense'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => setState(() => _showConfirm = false),
              child: Text(context.tr('scan.back'), style: TextStyle(color: AppColors.textSecondaryFor(context))),
            ),
          ),
        ],
      ),
    );
  }
}
