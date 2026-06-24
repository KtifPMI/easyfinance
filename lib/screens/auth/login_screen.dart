import 'package:flutter/material.dart';
import '../components/common/app_button.dart';
import '../components/common/app_input.dart';
import '../theme/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginCtrl = TextEditingController(text: 'demo@easyfinance.ru');
  final _passCtrl = TextEditingController(text: '123456');
  bool _loading = false;

  void _login() {
    setState(() => _loading = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    });
  }

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
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
              const Spacer(),
              AppInput(label: 'Email', controller: _loginCtrl, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 8),
              AppInput(label: 'Пароль', controller: _passCtrl, obscureText: true),
              const SizedBox(height: 24),
              AppButton(title: 'Войти', onPressed: _login, loading: _loading),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {},
                child: Text('Создать аккаунт', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
