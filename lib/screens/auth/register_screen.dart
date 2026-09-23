import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../navigation/app_router.dart';
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

  String? _nameError;
  String? _emailError;
  String? _loginError;
  String? _passwordError;
  String? _confirmError;

  bool _confirmTouched = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    setState(() {
      _nameError = null;
      _emailError = null;
      _loginError = null;
      if (_confirmTouched && _confirmController.text.isNotEmpty && _passwordController.text != _confirmController.text) {
        _confirmError = _confirmMismatchText;
      } else {
        _confirmError = null;
      }
      _error = null;
    });
  }

  bool get _validEmail {
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return re.hasMatch(_emailController.text.trim());
  }

  String get _confirmMismatchText => context.tr('auth.password_mismatch');

  int _passwordStrength(String pwd) {
    if (pwd.isEmpty) return 0;
    var score = 0;
    if (pwd.length >= 8) score++;
    if (RegExp(r'[a-z]').hasMatch(pwd) && RegExp(r'[A-Z]').hasMatch(pwd)) score++;
    if (RegExp(r'\d').hasMatch(pwd)) score++;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(pwd)) score++;
    return score;
  }

  bool _validate() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final login = _loginController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    setState(() {
      _nameError = name.isEmpty ? context.tr('auth.register_required') : null;
      _emailError = email.isEmpty ? context.tr('auth.register_required') : (_validEmail ? null : context.tr('auth.invalid_email'));
      _loginError = login.isEmpty ? context.tr('auth.register_required') : null;
      _passwordError = password.isEmpty ? context.tr('auth.register_required') : null;
      _confirmTouched = true;
      _confirmError = confirm.isEmpty ? context.tr('auth.register_required') : (password != confirm ? context.tr('auth.password_mismatch') : null);
    });
    return _nameError == null && _emailError == null && _loginError == null && _passwordError == null && _confirmError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final login = _loginController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final store = context.read<FinanceStore>();
      final plannedStore = context.read<PlannedPaymentStore>();
      final authService = store.authService;
      final user = await authService.register(
        name: name,
        email: email,
        login: login,
        password: password,
      );
      if (!mounted) return;
      store.clearAuthExpired();

      try {
        await store.switchToAccount(store.authService.userId);
      } catch (_) {}
      if (user != null) store.saveUser(user);
      if (!mounted) return;

      final masterStatus = await authService.checkMasterStatus();
      if (!mounted) return;
      if (masterStatus.isActive && !masterStatus.isMasterCompleted) {
        Navigator.pushReplacementNamed(context, AppRouter.onboarding, arguments: masterStatus);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/main', (r) => false);
        store.fetchAllData();
        plannedStore.syncFromServer();
        NotificationService().rescheduleAll();
        NotificationService().trackAppOpen();
      }
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
    final strength = _passwordStrength(_passwordController.text);
    final showStrength = _passwordController.text.isNotEmpty;
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
                        error: _nameError,
                        onChanged: _onChanged,
                      ),
                      const SizedBox(height: 16),
                      AppInput(
                        label: context.tr('auth.email'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        error: _emailError,
                        onChanged: _onChanged,
                      ),
                      const SizedBox(height: 16),
                      AppInput(
                        label: context.tr('auth.login_hint'),
                        controller: _loginController,
                        error: _loginError,
                        onChanged: _onChanged,
                      ),
                      const SizedBox(height: 16),
                      AppInput(
                        label: context.tr('auth.password_hint'),
                        controller: _passwordController,
                        obscureText: true,
                        error: _passwordError,
                        onChanged: _onChanged,
                      ),
                      if (showStrength) ...[
                        const SizedBox(height: 8),
                        _StrengthIndicator(strength: strength),
                        const SizedBox(height: 4),
                        Text(
                          strength <= 1 ? context.tr('auth.password_weak') : (strength == 2 ? context.tr('auth.password_medium') : context.tr('auth.password_strong')),
                          style: TextStyle(
                            fontSize: 13,
                            color: strength <= 1 ? AppColors.danger : (strength == 2 ? Colors.orange : AppColors.success),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      AppInput(
                        label: context.tr('auth.password_confirm'),
                        controller: _confirmController,
                        obscureText: true,
                        error: _confirmError,
                        onChanged: _onChanged,
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

class _StrengthIndicator extends StatelessWidget {
  final int strength;
  const _StrengthIndicator({required this.strength});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (i) {
        final filled = i < strength;
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: strength == 0
                  ? AppColors.borderFor(context)
                  : (filled
                      ? (strength <= 1
                          ? AppColors.danger
                          : (strength == 2 ? Colors.orange : AppColors.success))
                      : AppColors.borderFor(context)),
            ),
          ),
        );
      }),
    );
  }
}