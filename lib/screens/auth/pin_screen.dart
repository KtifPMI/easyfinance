import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../components/common/screen_scaffold.dart';
import '../../components/common/app_card.dart';
import '../../theme/theme.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  String _error = '';
  bool _loading = true;
  bool _hasExistingPin = false;
  int _step = 0; // 0 = enter existing, 1 = enter new, 2 = confirm new
  String _newPin = '';

  @override
  void initState() {
    super.initState();
    _loadExistingPin();
  }

  Future<void> _loadExistingPin() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString('easyfinance_pin');
    setState(() {
      _hasExistingPin = pin != null && pin.isNotEmpty;
      _loading = false;
    });
  }

  Future<void> _verifyPin() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('easyfinance_pin') ?? '';
    if (_pin == stored) {
      if (mounted) Navigator.pushReplacementNamed(context, '/main');
    } else {
      setState(() {
        _error = context.tr('auth.wrong_pin');
        _pin = '';
      });
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _setNewPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('easyfinance_pin', _pin);
    if (mounted) Navigator.pushReplacementNamed(context, '/main');
  }

  void _onDigit(String d) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = '';
    });
    HapticFeedback.lightImpact();
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_step == 0) {
          _verifyPin();
        } else if (_step == 1) {
          setState(() {
            _newPin = _pin;
            _pin = '';
            _step = 2;
          });
        } else if (_step == 2) {
          if (_pin == _newPin) {
            _setNewPin();
          } else {
            setState(() {
              _error = context.tr('auth.pins_dont_match');
              _pin = '';
              _step = 1;
              _newPin = '';
            });
            HapticFeedback.heavyImpact();
          }
        }
      });
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
      HapticFeedback.lightImpact();
    }
  }

  void _onForgotPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('easyfinance_pin');
    setState(() {
      _hasExistingPin = false;
      _step = 1;
      _pin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final title = !_hasExistingPin && _step == 0
        ? context.tr('auth.setup_pin')
        : _step == 1
            ? context.tr('auth.enter_new_pin')
            : _step == 2
                ? context.tr('auth.confirm_pin')
                : context.tr('auth.enter_pin');

    return ScreenScaffold(
      title: '',
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.lock_outline, size: 64, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          if (_hasExistingPin && _step == 0) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _onForgotPin,
              child: Text(
                context.tr('auth.forgot_pin'),
                style: TextStyle(color: AppColors.primary, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 32),
          _buildDots(),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_error, style: TextStyle(color: AppColors.expense, fontSize: 13)),
          ],
          const Spacer(),
          _buildKeypad(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < _pin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppColors.primary : AppColors.surfaceFor(context),
            border: Border.all(color: _error.isNotEmpty ? AppColors.expense : AppColors.textSecondaryFor(context)),
          ),
        );
      }),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
        ['', '0', '⌫'],
      ].map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: row.map((d) {
            if (d.isEmpty) return const SizedBox(width: 72, height: 72);
            return GestureDetector(
              onTap: () {
                if (d == '⌫') {
                  _onDelete();
                } else {
                  _onDigit(d);
                }
              },
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: d == '⌫' ? AppColors.backgroundFor(context) : AppColors.surfaceFor(context),
                  borderRadius: BorderRadius.circular(36),
                ),
                alignment: Alignment.center,
                child: d == '⌫'
                    ? Icon(Icons.backspace_outlined, color: AppColors.textSecondaryFor(context))
                    : Text(d, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
