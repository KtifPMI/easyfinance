import 'package:flutter/material.dart';
import '../../theme/theme.dart';

class CalculatorInput extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  const CalculatorInput({super.key, required this.controller, this.label});

  @override
  State<CalculatorInput> createState() => _CalculatorInputState();
}

class _CalculatorInputState extends State<CalculatorInput> {
  String _expression = '';
  String _result = '';
  int _parsePos = 0;

  @override
  void initState() {
    super.initState();
    _expression = widget.controller.text;
    _result = _evaluate(_expression);
  }

  void _onKey(String value) {
    setState(() {
      if (value == 'C') {
        _expression = '';
        _result = '';
      } else if (value == '⌫') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
          _result = _evaluate(_expression);
        }
      } else if (value == '=') {
        if (_result.isNotEmpty && _result != 'Error') {
          _expression = _result;
          _result = '';
        }
      } else {
        _expression += value;
        _result = _evaluate(_expression);
      }
      widget.controller.text = _expression;
    });
  }

  String _formatDisplay(String raw) {
    if (raw.isEmpty) return '0';
    final parts = raw.split(RegExp(r'[+\-×÷]'));
    final result = StringBuffer();
    int rawPos = 0;
    for (int i = 0; i < parts.length; i++) {
      if (i > 0) {
        result.write(raw[rawPos]);
        rawPos++;
      }
      final num = parts[i];
      if (num.isEmpty) continue;
      if (num.contains('.')) {
        final dotParts = num.split('.');
        final intFormatted = _addSpaces(dotParts[0]);
        result.write('$intFormatted.${dotParts[1]}');
      } else {
        result.write(_addSpaces(num));
      }
      rawPos += num.length;
    }
    return result.toString();
  }

  String _addSpaces(String num) {
    if (num.isEmpty) return num;
    return num.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
  }

  String _evaluate(String expr) {
    if (expr.isEmpty) return '';
    try {
      final cleaned = expr.replaceAll('×', '*').replaceAll('÷', '/').replaceAll(' ', '');
      _parsePos = 0;
      final result = _parseExpr(cleaned);
      if (result == result.toInt().toDouble()) return result.toInt().toString();
      return result.toStringAsFixed(2);
    } catch (_) {
      return '';
    }
  }

  double _parseExpr(String s) {
    double result = _parseTerm(s);
    while (_parsePos < s.length) {
      if (s[_parsePos] == '+') { _parsePos++; result += _parseTerm(s); }
      else if (s[_parsePos] == '-') { _parsePos++; result -= _parseTerm(s); }
      else { break; }
    }
    return result;
  }

  double _parseTerm(String s) {
    double result = _parseFactor(s);
    while (_parsePos < s.length) {
      if (s[_parsePos] == '*') { _parsePos++; result *= _parseFactor(s); }
      else if (s[_parsePos] == '/') { _parsePos++; final d = _parseFactor(s); if (d != 0) result /= d; }
      else { break; }
    }
    return result;
  }

  double _parseFactor(String s) {
    if (_parsePos < s.length && s[_parsePos] == '(') {
      _parsePos++;
      final val = _parseExpr(s);
      if (_parsePos < s.length && s[_parsePos] == ')') _parsePos++;
      return val;
    }
    final start = _parsePos;
    while (_parsePos < s.length && (int.tryParse(s[_parsePos]) != null || s[_parsePos] == '.')) { _parsePos++; }
    return double.tryParse(s.substring(start, _parsePos)) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
          const SizedBox(height: 8),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.cardFor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_result.isNotEmpty && _result != _expression)
                Text(_addSpaces(_result), style: TextStyle(fontSize: 15, color: AppColors.textSecondaryFor(context))),
              Text(_expression.isEmpty ? '0' : _formatDisplay(_expression), style: TextStyle(fontSize: 33, fontWeight: FontWeight.w700, color: AppColors.textFor(context))),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildRow(['÷', '7', '8', '9']),
        const SizedBox(height: 4),
        _buildRow(['×', '4', '5', '6']),
        const SizedBox(height: 4),
        _buildRow(['-', '1', '2', '3']),
        const SizedBox(height: 4),
        _buildRow(['+', '0', '.', 'C']),
        const SizedBox(height: 4),
        _buildRow(['', '⌫', '00', '=']),
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      children: keys.map((k) {
        if (k.isEmpty) return const Expanded(child: SizedBox.shrink());
        final isOp = ['÷', '×', '-', '+', '='].contains(k);
        final isSpecial = ['C', '⌫'].contains(k);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              onTap: () => _onKey(k == '00' ? '00' : k),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isOp ? AppColors.primary.withValues(alpha: 0.15) : isSpecial ? AppColors.expense.withValues(alpha: 0.1) : AppColors.cardFor(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(k, style: TextStyle(
                    fontSize: 19,
                    fontWeight: isOp ? FontWeight.w700 : FontWeight.w500,
                    color: isOp ? AppColors.primary : isSpecial ? AppColors.expense : AppColors.textFor(context),
                  )),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
