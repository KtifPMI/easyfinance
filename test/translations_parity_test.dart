import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Коды локалей, объявленные в main.dart. ru — источник истины.
const _locales = ['ru', 'en', 'de', 'es', 'fr', 'it', 'pt', 'tr'];

Map<String, dynamic> _loadLocale(String code) {
  final file = File('assets/translations/$code.json');
  return json.decode(file.readAsStringSync(encoding: utf8)) as Map<String, dynamic>;
}

void main() {
  test('all locales share the exact key set of ru.json', () {
    final reference = _loadLocale('ru').keys.toSet();

    for (final code in _locales.where((c) => c != 'ru')) {
      final keys = _loadLocale(code).keys.toSet();
      expect(
        keys.difference(reference),
        isEmpty,
        reason: '$code.json содержит ключи, которых нет в ru.json',
      );
      expect(
        reference.difference(keys),
        isEmpty,
        reason: '$code.json не содержит ключей из ru.json',
      );
    }
  });

  test('no locale keeps ru.json key order', () {
    final order = _loadLocale('ru').keys.toList();

    for (final code in _locales) {
      expect(_loadLocale(code).keys.toList(), order, reason: 'порядок ключей в $code.json отличается');
    }
  });

  test('translations are non-empty and keep {placeholders}', () {
    final ru = _loadLocale('ru');
    final placeholders = RegExp(r'\{(\w+)\}');

    for (final code in _locales) {
      for (final entry in _loadLocale(code).entries) {
        final value = entry.value;
        expect(value, isA<String>(), reason: '${entry.key} в $code.json не строка');
        expect((value as String).trim(), isNotEmpty, reason: '${entry.key} в $code.json пуст');
        expect(
          placeholders.allMatches(value).map((m) => m.group(0)).toSet(),
          placeholders.allMatches(ru[entry.key] as String).map((m) => m.group(0)).toSet(),
          reason: 'плейсхолдеры в ${entry.key} ($code) отличаются от ru',
        );
      }
    }
  });

  test('non-russian locales do not leak untranslated russian text', () {
    // settings.language_ru намеренно остаётся «Русский» — это название языка.
    const cyrillic = 'абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ';
    const allowed = {'settings.language_ru'};

    for (final code in _locales.where((c) => c != 'ru')) {
      final leaks = _loadLocale(code)
          .entries
          .where((e) => !allowed.contains(e.key) && (e.value as String).contains(RegExp('[$cyrillic]')))
          .map((e) => e.key)
          .toList();
      expect(leaks, isEmpty, reason: 'русский текст без перевода в $code.json: $leaks');
    }
  });

  test('every demo.* key referenced by mock_data.dart exists in all locales', () {
    final source = File('lib/services/mock_data.dart').readAsStringSync();
    final keys = RegExp(r"'(demo\.[a-z_.]+)'").allMatches(source).map((m) => m.group(1)!).toSet();
    expect(keys, isNotEmpty, reason: 'в mock_data.dart не найдено ни одного demo.* ключа');

    for (final code in _locales) {
      final locale = _loadLocale(code);
      for (final key in keys) {
        expect(locale.containsKey(key), isTrue, reason: 'ключ $key отсутствует в $code.json');
      }
    }
  });
}
