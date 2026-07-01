import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_button.dart';
import '../../services/api_client.dart' show ApiException;
import '../../store/finance_store.dart';
import '../../theme/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _mailCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _mailCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final login = _loginCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final mail = _mailCtrl.text.trim();

    if (login.isEmpty || pass.isEmpty || name.isEmpty || mail.isEmpty) {
      setState(() => _error = 'Все поля обязательны');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final store = context.read<FinanceStore>();
      final api = store.authService.apiService;
      await api.client.post('users.post', body: {
        'request': {
          'request_data': {
            'user': {'login': login, 'password': pass, 'name': name, 'mail': mail},
          },
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Регистрация успешна! Теперь войдите.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      setState(() => _error = '${e.message} (код: ${e.code})');
    } catch (e) {
      setState(() => _error = 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Text('Создать аккаунт', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(height: 32),
              TextField(
                controller: _loginCtrl,
                decoration: InputDecoration(labelText: 'Логин', filled: true, fillColor: AppColors.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Пароль', filled: true, fillColor: AppColors.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: 'Имя', filled: true, fillColor: AppColors.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _mailCtrl,
                decoration: InputDecoration(labelText: 'Email', filled: true, fillColor: AppColors.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: AppColors.expense, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              AppButton(title: 'Зарегистрироваться', onPressed: _register, loading: _loading),
            ],
          ),
        ),
      ),
    );
  }
}
