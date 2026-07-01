import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_button.dart';
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

    if (pass.length > 40) {
      setState(() => _error = 'Пароль не должен превышать 40 символов');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final store = context.read<FinanceStore>();
      final apiClient = store.apiClient;

      // 1. Формируем URL-параметры для подписи (БЕЗ uid, т.к. пользователь ещё не зарегистрирован)
      final urlParams = {
        'method': 'users.post',
        'app_id': apiClient.appId,
      };

      // 2. Рассчитываем подпись: sig = md5(secret_key + params)
      // params в том же порядке, что и в URL
      final paramsStr = 'method=users.post&app_id=${apiClient.appId}';
      final sig = apiClient.calculateSig(paramsStr);

      // 3. Формируем URL
      final uri = Uri.parse('https://api.easyfinance.ru/v2/')
          .replace(queryParameters: {
        ...urlParams,
        'sig': sig,
      });

      // 4. Формируем тело запроса по документации (стр. 41)
      final body = jsonEncode({
        'request': {
          'request_info': {
            'method': 'users.post',
          },
          'request_data': {
            'user': {
              'login': login,
              'password': pass,
              'name': name,
              'mail': mail,
            },
          },
        },
      });

      // 5. Отправляем POST-запрос
      final response = await apiClient.postRaw(uri, body);

      // 6. Парсим ответ
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final resp = decoded['response'] as Map<String, dynamic>?;
      final responseData = resp?['response_data'] as Map<String, dynamic>?;

      // Проверяем наличие ошибок в ответе
      if (responseData != null && responseData.containsKey('errors')) {
        final errors = responseData['errors'] as List<dynamic>;
        if (errors.isNotEmpty) {
          final first = errors.first as Map<String, dynamic>;
          final text = first['text']?.toString() ?? 'Unknown error';
          final code = first['code']?.toString() ?? '';
          throw Exception('Ошибка $code: $text');
        }
      }

      // 7. Обрабатываем успешный ответ
      final users = responseData?['users'];
      
      if (users != null) {
        final userId = users['id']?.toString();
        final accessToken = users['access_token']?.toString();

        if (accessToken != null && accessToken.isNotEmpty) {
          // Партнёрское приложение — токен вернулся сразу
          apiClient.setAuth(accessToken: accessToken, userId: userId);
          await store.authService.saveCredentials(
            appId: apiClient.appId,
            secretKey: apiClient.secretKey,
            accessToken: accessToken,
            userId: userId,
          );
          
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/main', (r) => false);
          }
        } else {
          // Обычное приложение — нужно авторизоваться через OAuth
          if (mounted) {
            setState(() => _error = 'Регистрация успешна! Теперь войдите через EasyFinance.ru');
            // Через 2 секунды переходим на экран входа
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                Navigator.pop(context); // Возврат на экран входа
              }
            });
          }
        }
      } else {
        if (mounted) {
          setState(() => _error = 'Неожиданный ответ сервера');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Ошибка: $e');
      }
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
              Text('Создать аккаунт', 
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(height: 32),
              TextField(
                controller: _loginCtrl,
                decoration: InputDecoration(
                  labelText: 'Логин', 
                  filled: true, 
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), 
                    borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Пароль (макс. 40 символов)', 
                  filled: true, 
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), 
                    borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Имя', 
                  filled: true, 
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), 
                    borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _mailCtrl,
                decoration: InputDecoration(
                  labelText: 'Email', 
                  filled: true, 
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), 
                    borderSide: BorderSide.none)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, 
                  style: TextStyle(color: AppColors.expense, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              AppButton(
                title: 'Зарегистрироваться', 
                onPressed: _register, 
                loading: _loading),
            ],
          ),
        ),
      ),
    );
  }
}
