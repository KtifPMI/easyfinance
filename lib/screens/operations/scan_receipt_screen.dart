import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/cloud_ocr_service.dart';
import '../../store/finance_store.dart';
import '../../models/operation.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';
import '../../utils/translate_category.dart';
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
  String? _ocrSource;
  String? _ocrLog;
  bool _showConfirm = false;
  bool _saving = false;

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
    final picked = await _picker.pickImage(source: source);
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

  /// Converts a receipt photo to high-contrast black & white.
  /// Thermal prints and faded receipts benefit heavily from binarization
  /// before OCR вЂ” it turns barely-visible gray text into sharp black.
  File _preprocessImage(File inputFile) {
    final bytes = inputFile.readAsBytesSync();
    final original = img.decodeImage(bytes);
    if (original == null) return inputFile;

    final gray = img.grayscale(original);
    for (var y = 0; y < gray.height; y++) {
      for (var x = 0; x < gray.width; x++) {
        final p = gray.getPixel(x, y);
        final lum = p.r.toInt();
        gray.setPixel(x, y, lum > 100 ? img.ColorRgba8(255, 255, 255, 255) : img.ColorRgba8(0, 0, 0, 255));
      }
    }
    final tempFile = File('${Directory.systemTemp.path}/receipt_preprocessed.jpg');
    tempFile.writeAsBytesSync(img.encodeJpg(gray, quality: 95));
    return tempFile;
  }

  Future<void> _scanReceipt(FinanceStore store) async {
    if (_image == null) return;
    String? ocrSource;
    String? ocrLog;
    try {
      String? text;
      final processed = _preprocessImage(_image!);

      // Try Yandex Vision cloud OCR first (much better for Cyrillic)
      if (CloudOcrService.isConfigured) {
        try {
          final cloudResult = await CloudOcrService.recognize(processed);
          text = cloudResult.text;
          ocrSource = 'Yandex Vision';
          ocrLog = 'OK: ${text.length} СЃРёРјРІРѕР»РѕРІ';
        } on CloudOcrException catch (e) {
          ocrSource = 'Yandex Vision (РѕС€РёР±РєР°)';
          ocrLog = e.message;
          // Cloud failed вЂ” fall through to ML Kit
        } catch (e) {
          ocrSource = 'Yandex Vision (РёСЃРєР»СЋС‡РµРЅРёРµ)';
          ocrLog = e.toString();
        }
      } else {
        ocrLog = 'РќРµ РЅР°СЃС‚СЂРѕРµРЅ (РєР»СЋС‡: ${CloudOcrService.apiKey.isEmpty ? "РїСѓСЃС‚РѕР№" : "РµСЃС‚СЊ"}, folder: ${CloudOcrService.folderId.isEmpty ? "РїСѓСЃС‚РѕР№" : "РµСЃС‚СЊ"})';
      }

      // Fallback to on-device ML Kit
      text ??= await _runMlKit(processed);
      ocrSource ??= 'ML Kit (on-device)';

      if (!mounted) return;
      if (text == null || text.isEmpty) {
        setState(() { _error = context.tr('scan.error_recognize'); _scanning = false; });
        return;
      }
      _parseReceiptText(text, store);
      setState(() {
        _recognizedText = text;
        _ocrSource = ocrSource;
        _ocrLog = ocrLog;
        _scanning = false;
        _showConfirm = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = context.tr('scan.error_format', namedArgs: {'error': '$e'}); _scanning = false; });
    }
  }

  Future<String?> _runMlKit(File image) async {
    final inputImage = InputImage.fromFile(image);
    final result = await _textRecognizer.processImage(inputImage);
    final text = result.text;
    return text.isNotEmpty ? text : null;
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
    _commentCtrl.text = _extractItems(lines, _parsedStore);
  }

  String _normalize(String s) {
    return s
        .replaceAll('A', 'Р°').replaceAll('a', 'Р°')
        .replaceAll('B', 'РІ').replaceAll('b', 'РІ')
        .replaceAll('C', 'СЃ').replaceAll('c', 'СЃ')
        .replaceAll('E', 'Рµ').replaceAll('e', 'Рµ')
        .replaceAll('H', 'РЅ').replaceAll('h', 'РЅ')
        .replaceAll('I', 'Рё').replaceAll('i', 'Рё')
        .replaceAll('K', 'Рє').replaceAll('k', 'Рє')
        .replaceAll('M', 'Рј').replaceAll('m', 'Рј')
        .replaceAll('O', 'Рѕ').replaceAll('o', 'Рѕ')
        .replaceAll('P', 'СЂ').replaceAll('p', 'СЂ')
        .replaceAll('R', 'Рі').replaceAll('r', 'Рі')
        .replaceAll('T', 'С‚').replaceAll('t', 'С‚')
        .replaceAll('U', 'Рё').replaceAll('u', 'Рё')
        .replaceAll('X', 'С…').replaceAll('x', 'С…')
        .replaceAll('Y', 'Сѓ').replaceAll('y', 'Сѓ')
        .toLowerCase();
  }

  String _extractItems(List<String> lines, String storeName) {
    final skipKeywords = ['РёС‚РѕРіРѕ', 'РёС‚РѕРі', 'СЃСѓРјРјР°', 'Рє РѕРїР»Р°С‚Рµ', 'РѕРїР»Р°С‚Р°', 'СЃРґР°С‡Р°',
      'РЅР°Р»РёС‡РЅС‹РјРё', 'Р±РµР·РЅР°Р»', 'РєР°СЂС‚Р°', 'РєР°СЂС‚Сѓ', 'РЅРґСЃ', 'РєРєС‚', 'СЌРєР»Р·', 'С„Рї',
      'С‡РµРє', 'РєР°СЃСЃРёСЂ', 'РїСЂРѕРґР°РІРµС†', 'РїРѕРєСѓРїР°С‚РµР»СЊ', 'СЃРїР°СЃРёР±Рѕ', 'Р¶РґС‘Рј', 'Р¶РґРµРј',
      '---------', '=======', 'С‚РµСЂРјРёРЅР°Р»', 'СЌРєР·РµРјРїР»СЏСЂ', 'Р°РІР°РЅСЃ', 'РїСЂРµРґРѕРїР»Р°С‚'];
    final amountPattern = RegExp(r'[\d]+[.,]\d{2}');
    final items = <String>[];

    for (final line in lines) {
      final lower = line.toLowerCase();
      // Skip lines with skip keywords
      if (skipKeywords.any((k) => lower.contains(k))) continue;
      // Skip store name line
      if (storeName.isNotEmpty && lower.contains(storeName.toLowerCase().substring(0, storeName.length.clamp(0, 8)))) continue;
      // Skip pure number/amount lines
      if (amountPattern.hasMatch(line) && line.replaceAll(RegExp(r'[\d.,\s%]+'), '').length < 3) continue;
      // Skip very short lines
      if (line.length < 4) continue;
      // Skip lines that are mostly numbers
      final digits = RegExp(r'\d').allMatches(line).length;
      if (digits > line.length * 0.6) continue;

      // Clean up: remove trailing amounts and quantities
      var cleaned = line
          .replaceAll(RegExp(r'\s+[\d]+[.,]\d{2}\s*$'), '')
          .replaceAll(RegExp(r'\s+\d+\s*С€С‚\.?\s*$'), '')
          .replaceAll(RegExp(r'\s+\d+[.,]\d+\s*РєРі\.?\s*$'), '')
          .replaceAll(RegExp(r'\s+x\d+\s*$'), '')
          .replaceAll(RegExp(r'\s+\*\s*\d+\s*$'), '')
          .trim();

      if (cleaned.length >= 3 && cleaned.length <= 60) {
        items.add(cleaned);
      }
    }

    if (items.isEmpty) return storeName.isNotEmpty ? storeName : '';
    return items.take(8).join(', ');
  }

  String _findStoreName(List<String> lines) {
    final skipExact = ['СЌРєР»Р·', 'РєРєС‚', 'СЂРЅ РєРєС‚', 'С„Рґ', 'С„Рї', 'Р·РЅ РєРєС‚', 'Р·РЅ РєС‚',
      'СЃРёСЃС‚РµРјР°', 'РјРµСЂРєСѓСЂРёР№', 'С€С‚СЂРёС…', 'Р°С‚РѕР»', 'СЌРІРѕС‚РѕСЂ',
      'РєР°С‚Р°Р»РѕРі', 'catalog', 'easyfinance', 'untitled', 'figma', 'telegram', 'explorer'];

    final headerWords = ['РєР°СЃСЃРѕРІС‹Р№', 'С‡РµРєР°', 'С‡РµРєРѕРј', 'СЃР°Р№С‚', 'С‚РµР»', 'Р°РґСЂРµСЃ',
      'РѕРіСЂРЅ', 'СЌР»', 'СЂРёСЃСѓРЅРѕРє', 'СЏРЅРґРµРєСЃ', 'РєР°СЂС‚РёРЅРє'];

    final storeClues = ['СЂРµСЃС‚РѕСЂР°РЅ', 'РјР°РіР°Р·РёРЅ', 'РєР°С„Рµ', 'Р±Р°СЂ', 'СЃС‚РѕР»РѕРІР°СЏ',
      'РєР°Р»СЊСЏРЅРЅР°СЏ', 'РєРѕС„РµР№РЅ', 'РїРёС†С†РµСЂ', 'Р°РїС‚РµРє', 'СЃРїРѕСЂС‚', 'fix', 'РјРµРіР°',
      'Р»РµРЅС‚Р°', 'Р°С€Р°РЅ', 'РїСЏС‚РµСЂРѕС‡Рє', 'РјР°РіРЅРёС‚', 'РІРєСѓСЃРІРёР»Р»', 'РїРµСЂРµРєСЂС‘СЃС‚РѕРє',
      'РѕРєРµР№', 'СЃРІРµС‚РѕС„РѕСЂ', 'РґРёРєСЃРё', 'match', 'РІР±', 'РјРІРёРґРµРѕ', 'dns',
      'СЃР°РјРѕРєР°С‚', 'СЏРЅРґРµРєСЃ'];

    for (final line in lines) {
      final lower = line.toLowerCase();
      final norm = _normalize(line);
      if (line.length < 3) continue;
      if (skipExact.any((w) => lower == w || norm == w)) continue;
      if (headerWords.any((w) => lower.contains(w))) continue;
      if (storeClues.any((c) => norm.contains(c) || lower.contains(c))) return _cleanStoreName(line);
    }
    for (final line in lines) {
      final lower = line.toLowerCase();
      final norm = _normalize(line);
      if (line.length < 3) continue;
      if (skipExact.any((w) => lower == w || norm == w)) continue;
      if (headerWords.any((w) => lower.contains(w))) continue;
      if (RegExp(r'[Р°-СЏС‘]{3,}').hasMatch(norm)) return _cleanStoreName(line);
    }
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (line.length < 5) continue;
      if (headerWords.any((w) => lower.contains(w))) continue;
      if (lower.contains('РёРї ') || lower.contains('РѕРѕРѕ')) return _cleanStoreName(line);
    }
    return '';
  }

  String _cleanStoreName(String line) {
    var s = line.replaceAll(RegExp(r'^[\d\s./*#:-]+'), '').trim();
    s = s.replaceAll(RegExp(r'["В«В»""]'), '').trim();
    if (s.length > 40) s = s.substring(0, 40);
    return s;
  }

  String? _detectCategory(String normalizedText, List<dynamic> categories) {
    final categoryClues = {
      'РїРёС‚Р°РЅРёРµ': ['СЂРµСЃС‚РѕСЂР°РЅ', 'РєР°С„Рµ', 'СЃС‚РѕР»РѕРІР°СЏ', 'Р±Р°СЂ', 'РєРѕС„РµР№РЅ', 'РїРёС†С†РµСЂ', 'РµРґР°', 'РїСЂРѕРґСѓРєС‚', 'Р±Р»СЋРґРѕ', 'РїРѕСЂС†Рё', 'РІРёРЅРѕ', 'РїРёРІРѕ', 'РєРѕС„Рµ', 'С‡Р°Р№', 'РјСЏСЃРѕ', 'СЂС‹Р±Р°', 'СЃР°Р»Р°С‚', 'СЃСѓРї', 'С…Р»РµР±', 'РјРѕР»РѕРєРѕ', 'СЃС‹СЂ', 'РєРѕР»Р±Р°СЃ', 'РЅР°РїРёС‚РѕРє', 'СЃРѕРє', 'РґРµСЃРµСЂС‚', 'РїРёС†С†Р°', 'СЂРѕР»Р»', 'СЃСѓС€Рё', 'Р±СѓСЂРіРµСЂ', 'РєР°СЂС‚РѕС„', 'СЃРІРёРЅРёРЅ', 'РєСѓСЂРёС†Р°', 'РєРѕС‚Р»РµС‚', 'РїРµР»СЊРјРµРЅ', 'Р±Р»РёРЅС‹', 'РјРѕСЂРѕР¶РµРЅ', 'С€РѕРєРѕР»Р°Рґ', 'С‚РѕСЂС‚', 'РїРёСЂРѕР¶РЅ', 'Р±СѓС‚РµСЂР±СЂРѕРґ', 'Р°Р·Сѓ', 'РїР°СЃС‚Р°', 'РјР°РєР°СЂРѕРЅ', 'РјР°СЃР»Рѕ', 'С‚РІРѕСЂРѕРі', 'СЏРёС†', 'РіРѕРІСЏРґРёРЅ', 'Р»РѕСЃРѕСЃСЊ', 'РєСЂРµРІРµС‚Рє', 'РєР°Р»СЊРјР°СЂ'],
      'Р°РІС‚РѕРјРѕР±РёР»СЊ': ['Р°РІС‚Рѕ', 'Р·Р°РїСЂР°РІРє', 'Р°СЌСЂРѕ', 'Р°Р·СЃ', 'С€РёРЅРѕРјРѕРЅС‚Р°Р¶', 'СЃС‚Рѕ', 'Р±РµРЅР·РёРЅ', 'РґРёР·РµР»', 'С‚РѕРїР»РёРІ', 'Р°Рё-95', 'Р°Рё-92'],
      'РґРѕСЃСѓРі Рё РѕС‚РґС‹С…': ['РєРёРЅРѕ', 'С‚РµР°С‚СЂ', 'РєРѕРЅС†РµСЂС‚', 'РїР°СЂРє', 'СЂР°Р·РІР»РµРє', 'Р±РёР»РµС‚'],
      'РґРѕРјР°С€РЅРµРµ С…РѕР·СЏР№СЃС‚РІРѕ': ['РјР°РіР°Р·РёРЅ', 'С…РѕР·', 'СЃС‚СЂРѕР№РјР°С‚РµСЂ', 'РјРµР±РµР»СЊ', 'РѕР±РѕРё', 'РєСЂР°СЃРє', 'Р»Р°РјРёРЅР°С‚'],
      'РїСЂРѕРµР·Рґ, С‚СЂР°РЅСЃРїРѕСЂС‚': ['С‚Р°РєСЃРё', 'РјРµС‚СЂРѕ', 'Р°РІС‚РѕР±СѓСЃ', 'С‚СЂР°РЅСЃРїРѕСЂС‚', 'Р±РёР»РµС‚'],
      'РѕРґРµР¶РґР°, РѕР±СѓРІСЊ, Р°РєСЃРµСЃСЃСѓР°СЂС‹': ['РѕРґРµР¶Рґ', 'РѕР±СѓРІСЊ', 'Р°РєСЃРµСЃСЃСѓР°СЂ', 'С„СѓС‚Р±РѕР»Рє', 'С€С‚Р°РЅ', 'РєСѓСЂС‚Рє', 'РґР¶РёРЅСЃ', 'С€Р°РїРє'],
      'РјРµРґРёС†РёРЅР°': ['Р»РµРєР°СЂСЃС‚РІ', 'С‚Р°Р±Р»РµС‚Рє', 'Р°РїС‚РµС‡', 'РєР°РїРµР»', 'РјРёРєСЃС‚СѓСЂ', 'РїР»Р°СЃС‚С‹СЂ', 'РІРёС‚Р°РјРёРЅ', 'Р°РЅС‚РёР±РёРѕС‚РёРє'],
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
    final kwNorm = ['РёС‚РѕРі', 'РёС‚РѕРіРѕ', 'СЃСѓРјРјР°', 'СЃСѓРјРјС‹', 'Рє РѕРїР»Р°С‚Рµ', 'Рє onlate', 'РІСЃРµРіРѕ', 'РІcРµРіРѕ', 'РјС‚РѕРі'];
    final kwRaw = ['mtor', 'cymma', 'k onlate', 'itorg'];

    for (int i = lines.length - 1; i >= 0; i--) {
      final norm = _normalize(lines[i]);
      final raw = lines[i].toLowerCase();
      if (kwNorm.any((k) => norm.contains(k)) || kwRaw.any((k) => raw.contains(k))) {
        var nums = _extractNumbersAfterKeyword(lines[i]);
        if (nums.isEmpty) {
          for (int j = i + 1; j < lines.length && j <= i + 5; j++) {
            final jNums = _extractSignificantNumbers(lines[j]);
            if (jNums.isNotEmpty) { nums = jNums; break; }
          }
        }
        if (nums.isNotEmpty && nums.last >= 20) return nums.last.toStringAsFixed(0);
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
    final fallback = <double>[];
    for (final line in lines) {
      fallback.addAll(_extractSignificantNumbers(line));
    }
    if (fallback.isNotEmpty) {
      fallback.sort();
      return fallback.last.toStringAsFixed(0);
    }
    return '';
  }

  List<double> _extractSignificantNumbers(String s) {
    var prepared = s.replaceAll('Рћ', '0').replaceAll('Рѕ', '0');
    final regex = RegExp(r'\d[\d\s.,]*\d|\d+');
    final matches = regex.allMatches(prepared);
    final result = <double>[];
    for (final m in matches) {
      var numStr = m.group(0)!.replaceAll(' ', '').replaceAll(',', '.');
      if (numStr.contains('.')) {
        final parts = numStr.split('.');
        if (parts.length > 2) numStr = parts.join('');
      }
      final v = double.tryParse(numStr);
      if (v != null && v > 10) result.add(v);
    }
    return result;
  }

  List<double> _extractNumbersAfterKeyword(String line) {
    final norm = _normalize(line);
    final keywords = ['РёС‚РѕРі', 'РёС‚РѕРіРѕ', 'СЃСѓРјРјР°', 'Рє РѕРїР»Р°С‚Рµ', 'РІСЃРµРіРѕ'];
    int pos = -1;
    for (final kw in keywords) {
      final idx = norm.indexOf(kw);
      if (idx >= 0) { pos = idx; break; }
    }
    if (pos < 0) {
      final raw = line.toLowerCase();
      for (final kw in ['mtor', 'cymma', 'k onlate']) {
        final idx = raw.indexOf(kw);
        if (idx >= 0) { pos = idx; break; }
      }
    }
    if (pos < 0) return _extractSignificantNumbers(line);

    final after = line.substring(pos);
    final numPart = after.replaceAll(RegExp(r'^[^0-9]*'), '');
    var cleaned = numPart.replaceAll(' ', '').replaceAll(',', '.').replaceAll('Рћ', '0').replaceAll('Рѕ', '0');
    if (cleaned.contains('.')) {
      final parts = cleaned.split('.');
      if (parts.length > 2) cleaned = parts.join('');
    }
    final v = double.tryParse(cleaned);
    if (v != null && v > 0) return [v];

    return _extractSignificantNumbers(numPart);
  }

  Future<void> _save(FinanceStore store) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
      if (amount <= 0) return;
      if (store.accounts.isEmpty) return;

      final catId = _selectedCategoryId ?? store.categories.where((c) => c.type == 'expense').firstOrNull?.id;
      final now = DateTime.now();
      DateTime opDt = now;
      if (_dateCtrl.text.isNotEmpty) {
        final parsed = DateTime.tryParse(_dateCtrl.text);
        if (parsed != null) {
          opDt = DateTime(parsed.year, parsed.month, parsed.day, now.hour, now.minute, now.second);
        }
      }
      final clientId = now.microsecondsSinceEpoch.toString();

      final op = Operation(
        id: clientId,
        type: 'expense',
        amount: amount,
        date: formatApiDateTime(opDt),
        accountId: _selectedAccountId ?? store.accounts.first.id,
        categoryId: catId,
        comment: _commentCtrl.text.isNotEmpty ? _commentCtrl.text : context.tr('scan.receipt_comment', namedArgs: {'store': _parsedStore}),
        clientId: clientId,
      );

      await store.addOperation(op);
      if (!mounted) return;
      if (store.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(store.error!), backgroundColor: AppColors.danger),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('scan.expense_added', namedArgs: {'amount': amount.toStringAsFixed(0)})), backgroundColor: AppColors.success),
      );
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        return ScreenScaffold(
          title: context.tr('scan.title'),
          showLogo: false,
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
            child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: AppColors.expense)),
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
          if (_ocrSource != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _ocrLog != null && _ocrLog!.startsWith('OK') ? AppColors.success.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'OCR: $_ocrSource${_ocrLog != null ? '\n$_ocrLog' : ''}',
                style: Theme.of(context).textTheme.labelSmall!.copyWith(color: _ocrLog != null && _ocrLog!.startsWith('OK') ? AppColors.success : AppColors.warning),
              ),
            ),
            const SizedBox(height: 8),
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
              child: Text(_recognizedText!, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppColors.textSecondaryFor(context))),
            ),
            const SizedBox(height: 16),
          ],
          Text(context.tr('scan.account'), style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
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
          Text(context.tr('scan.category'), style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategoryId,
            decoration: InputDecoration(
              filled: true, fillColor: AppColors.cardFor(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: store.categories.where((c) => c.type == 'expense').map((c) => DropdownMenuItem<String>(value: c.id, child: Text(tCat(context, c.name)))).toList(),
            onChanged: (v) => setState(() => _selectedCategoryId = v),
          ),
          const SizedBox(height: 16),
          Text(context.tr('scan.amount'), style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
          const SizedBox(height: 4),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              filled: true, fillColor: AppColors.cardFor(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.textFor(context)),
          ),
          const SizedBox(height: 16),
          Text(context.tr('scan.date'), style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
          const SizedBox(height: 4),
          TextField(
            controller: _dateCtrl,
            decoration: InputDecoration(
              filled: true, fillColor: AppColors.cardFor(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            style: TextStyle(fontSize: 16, color: AppColors.textFor(context)),
          ),
          const SizedBox(height: 16),
          Text(context.tr('scan.comment'), style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
          const SizedBox(height: 4),
          TextField(
            controller: _commentCtrl,
            decoration: InputDecoration(
              filled: true, fillColor: AppColors.cardFor(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            style: TextStyle(fontSize: 16, color: AppColors.textFor(context)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : () => _save(store),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                  : Text(context.tr('scan.add_expense'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
