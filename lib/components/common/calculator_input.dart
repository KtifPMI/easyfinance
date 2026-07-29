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

  String _evaluate(String expr) {
    if (expr.isEmpty) return '';
    try {
      final cleaned = expr.replaceAll('×', '*').replaceAll('÷', '/');
      int _i = 0;

      double _parseExpr() {
        double result = _parseTerm();
        while (_i < cleaned.length) {
          if (cleaned[_i] == '+') { _i++; result += _parseTerm(); }
          else if (cleaned[_i] == '-') { _i++; result -= _parseTerm(); }
          else { break; }
        }
        return result;
      }

      double _parseTerm() {
        double result = _parseFactor();
        while (_i < cleaned.length) {
          if (cleaned[_i] == '*') { _i++; result *= _parseFactor(); }
          else if (cleaned[_i] == '/') { _i++; final d = _parseFactor(); if (d != 0) result /= d; }
          else { break; }
        }
        return result;
      }

      double _parseFactor() {
        if (_i < cleaned.length && cleaned[_i] == '(') {
          _i++;
          final val = _parseExpr();
          if (_i < cleaned.length && cleaned[_i] == ')') _i++;
          return val;
        }
        final start = _i;
        while (_i < cleaned.length && (int.tryParse(cleaned[_i]) != null || cleaned[_i] == '.')) _i++;
        return double.tryParse(cleaned.substring(start, _i)) ?? 0;
      }

      final result = _parseExpr();
      if (result == result.toInt().toDouble()) return result.toInt().toString();
      return result.toStringAsFixed(2);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
          const SizedBox(height: 8),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardFor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_result.isNotEmpty && _result != _expression)
                Text(_result, style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
              Text(_expression.isEmpty ? '0' : _expression, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textFor(context))),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildRow(['7', '8', '9', '÷']),
        const SizedBox(height: 4),
        _buildRow(['4', '5', '6', '×']),
        const SizedBox(height: 4),
        _buildRow(['1', '2', '3', '-']),
        const SizedBox(height: 4),
        _buildRow(['0', '.', '+', '=']),
        const SizedBox(height: 4),
        _buildRow(['C', '(', ')', '⌫']),
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      children: keys.map((k) {
        final isOp = ['÷', '×', '-', '+', '='].contains(k);
        final isSpecial = ['C', '⌫'].contains(k);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              onTap: () => _onKey(k),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isOp ? AppColors.primary.withValues(alpha: 0.15) : isSpecial ? AppColors.expense.withValues(alpha: 0.1) : AppColors.cardFor(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(k, style: TextStyle(
                    fontSize: 18,
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
