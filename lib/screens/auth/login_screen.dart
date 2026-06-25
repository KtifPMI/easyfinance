import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/common/app_button.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tryRestore();
  }

  Future<void> _tryRestore() async {
    final store = context.read<FinanceStore>();
    final restored = await store.authService.tryRestoreSession();
    if (restored && mounted) {
      setState(() => _loading = true);
      await store.fetchAllData();
      if (mounted) Navigator.pushReplacementNamed(context, '/main');
    }
  }

  void _startOAuth() async {
    final result = await Navigator.pushNamed(context, '/oauth');
    if (result == true && mounted) {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  void _skipLogin() {
    Navigator.pushReplacementNamed(context, '/main');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Icon(Icons.account_balance, size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              Text('EasyFinance', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(height: 8),
              Text('Ваш финансовый навигатор', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
              const SizedBox(height: 40),
              Text(
                'Войдите через EasyFinance.ru, чтобы получить доступ к вашим счетам, операциям и бюджету.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const Spacer(),
              AppButton(
                title: 'Войти через EasyFinance.ru',
                onPressed: _startOAuth,
                loading: _loading,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _skipLogin,
                child: Text('Пропустить (демо-режим)', style: TextStyle(color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
