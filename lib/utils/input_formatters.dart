import 'package:flutter/services.dart';

/// Formats the integer part of a number with a space as a thousands separator
/// (e.g. `1000000` -> `1 000 000`), preserving an optional decimal part.
class ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;

    String intPart;
    String fracPart = '';
    final sepIndex = text.indexOf(RegExp(r'[.,]'));
    if (sepIndex == -1) {
      intPart = text;
    } else {
      intPart = text.substring(0, sepIndex);
      final rawFrac = text.substring(sepIndex).replaceAll(RegExp(r'[^\d.,]'), '');
      final m = RegExp(r'^([.,])(\d{0,2}).*$').firstMatch(rawFrac);
      fracPart = m != null ? '${m[1]}${m[2]}' : '';
    }

    intPart = intPart.replaceAll(RegExp(r'[^\d]'), '');
    if (intPart.isEmpty) intPart = '0';

    final reversed = intPart.split('').reversed.toList();
    final grouped = <String>[];
    for (var i = 0; i < reversed.length; i++) {
      if (i != 0 && i % 3 == 0) grouped.add(' ');
      grouped.add(reversed[i]);
    }
    final intFormatted = grouped.join().split('').reversed.join();
    final result = intFormatted + fracPart;

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}
