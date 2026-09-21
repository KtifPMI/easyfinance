import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../components/common/app_logo.dart';
import '../../navigation/app_router.dart';
import '../../services/api_client.dart';
import '../../services/notification_service.dart';
import '../../store/finance_store.dart';
import '../../store/planned_payment_store.dart';
import '../../theme/theme.dart';

class NativeLoginScreen extends StatefulWidget {
  const NativeLoginScreen({super.key});

  @override
  State<NativeLoginScreen> createState() => _NativeLoginScreenState();
}

class _NativeLoginScreenState extends State<NativeLoginScreen> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final login = _loginController.text.trim();
    final password = _passwordController.text;
    if (login.isEmpty || password.isEmpty) {
      setState(() => _error = context.tr('auth.login_error'));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final store = context.read<FinanceStore>();
      final plannedStore = context.read<PlannedPaymentStore>();
      final authService = store.authService;
      final user = await authService.loginWithPassword(login: login, password: password);
      if (user != null) store.saveUser(user);
      store.clearAuthExpired();
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
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = context.tr('auth.login_error');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      const SizedBox(height: 48),
                      const AppLogo.hero(),
                      const SizedBox(height: 20),
                      Text(
                        context.tr('auth.subtitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: AppColors.textSecondaryFor(context)),
                      ),
                      const SizedBox(height: 40),
                      AppInput(
                        label: context.tr('auth.login_hint'),
                        controller: _loginController,
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 16),
                      AppInput(
                        label: context.tr('auth.password_hint'),
                        controller: _passwordController,
                        obscureText: true,
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.expense, fontSize: 14)),
                      ],
                      const SizedBox(height: 32),
                      AppButton(
                        title: context.tr('auth.enter'),
                        onPressed: _submit,
                        loading: _loading,
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        title: context.tr('auth.register'),
                        onPressed: () => Navigator.pushNamed(context, '/register'),
                        variant: 'outline',
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/oauth'),
                        child: Text(context.tr('auth.oauth_fallback'), style: TextStyle(color: AppColors.textSecondaryFor(context))),
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