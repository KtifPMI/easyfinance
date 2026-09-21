import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../services/api_client.dart';
import '../../services/notification_service.dart';
import '../../store/finance_store.dart';
import '../../store/planned_payment_store.dart';
import '../../theme/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _validEmail {
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return re.hasMatch(_emailController.text.trim());
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final login = _loginController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty || email.isEmpty || login.isEmpty || password.isEmpty) {
      setState(() => _error = context.tr('auth.register_required'));
      return;
    }
    if (!_validEmail) {
      setState(() => _error = context.tr('auth.invalid_email'));
      return;
    }
    if (password != confirm) {
      setState(() => _error = context.tr('auth.password_mismatch'));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final store = context.read<FinanceStore>();
      final plannedStore = context.read<PlannedPaymentStore>();
      final user = await store.authService.register(
        name: name,
        email: email,
        login: login,
        password: password,
      );
      if (user != null) store.saveUser(user);
      store.clearAuthExpired();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/main', (r) => false);
      store.fetchAllData();
      plannedStore.syncFromServer();
      NotificationService().rescheduleAll();
      NotificationService().trackAppOpen();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = _mapError(e.message);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = context.tr('auth.register_error_generic');
          _loading = false;
        });
      }
    }
  }

  String _mapError(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('логин') && s.contains('занят')) return context.tr('auth.error_login_taken');
    if (s.contains('занят') &&
        (s.contains('email') || s.contains('майл') || s.contains('адресе'))) {
      return context.tr('auth.error_email_taken');
    }
    return context.tr('auth.register_error_generic');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('auth.register')), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth > 400 ? 400.0 : constraints.maxWidth;
              return SingleChildScrollView(
                child: Container(
                  width: maxW,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppInput(
                        label: context.tr('auth.name'),
                        controller: _nameController,
                      ),
                      const SizedBox(height: 16),
                      AppInput(
                        label: context.tr('auth.email'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      AppInput(
                        label: context.tr('auth.login_hint'),
                        controller: _loginController,
                      ),
                      const SizedBox(height: 16),
                      AppInput(
                        label: context.tr('auth.password_hint'),
                        controller: _passwordController,
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      AppInput(
                        label: context.tr('auth.password_confirm'),
                        controller: _confirmController,
                        obscureText: true,
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.expense, fontSize: 14)),
                      ],
                      const SizedBox(height: 32),
                      AppButton(
                        title: context.tr('auth.register_submit'),
                        onPressed: _submit,
                        loading: _loading,
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}