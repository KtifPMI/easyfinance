import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../components/common/app_logo.dart';
import '../../navigation/app_router.dart';
import '../../services/api_client.dart';
import '../../services/notification_service.dart';
import '../../store/finance_store.dart';
import '../../store/locale_store.dart';
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
  bool _restoring = true;
  String? _error;

  static const Map<String, String> _langShortCode = {
    'ru': 'RUS', 'en': 'ENG', 'es': 'ESP', 'it': 'ITA',
    'fr': 'FRA', 'de': 'DEU', 'pt': 'POR', 'tr': 'TUR',
  };

  String _shortCode(String languageCode) =>
      _langShortCode[languageCode] ?? languageCode.toUpperCase();

  @override
  void initState() {
    super.initState();
    _tryRestore();
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _tryRestore() async {
    final store = context.read<FinanceStore>();
    final restored = await store.authService.tryRestoreSession();
    final prefs = await SharedPreferences.getInstance();
    final hasPin = await store.authService.hasPin();
    final startScreen = prefs.getString('easyfinance_start_screen') ?? 'main';
    final initialRoute = hasPin ? '/pin' : (startScreen == 'addOperation' ? '/add-operation' : '/main');
    if (!mounted) {
      setState(() => _restoring = false);
      return;
    }

    if (restored) {
      if (await _verifyAccountNotDeleted(store)) {
        if (!mounted) return;
        try {
          await store.switchToAccount(store.authService.userId);
        } catch (_) {}
        if (!mounted) return;
        try {
          final masterStatus = await store.authService.checkMasterStatus();
          if (!mounted) return;
          if (masterStatus.isActive && !masterStatus.isMasterCompleted) {
            Navigator.pushReplacementNamed(context, AppRouter.onboarding, arguments: masterStatus);
            return;
          }
        } catch (_) {}
        Navigator.pushReplacementNamed(context, initialRoute);
        store.fetchAllData();
        NotificationService().rescheduleAll();
        NotificationService().trackAppOpen();
        return;
      }
    } else if (!store.useMock) {
      Navigator.pushReplacementNamed(context, initialRoute);
      return;
    }
    if (mounted) setState(() => _restoring = false);
  }

  Future<bool> _verifyAccountNotDeleted(FinanceStore store) async {
    try {
      final api = store.authService.apiService;
      final user = await api.getUser();
      if (user.id.isNotEmpty && store.apiClient.userId != user.id) {
        store.apiClient.setAuth(accessToken: store.apiClient.accessToken ?? '', userId: user.id);
      }
      return true;
    } on ApiException catch (e) {
      if (e.code == 'ACCOUNT_DELETED') {
        store.handleAccountDeleted();
        return false;
      }
      return true;
    } catch (_) {
      // Нет сети или сервер недоступен — оставляем сессию как есть.
      return true;
    }
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
      store.clearAuthExpired();
      if (!mounted) return;
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
          _error = _mapLoginError(e.message);
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

  String _mapLoginError(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('invalid grant') || s.contains('invalid_grant')) {
      return context.tr('auth.invalid_credentials');
    }
    return raw;
  }

  void _skipLogin() {
    Navigator.pushReplacementNamed(context, '/main');
    NotificationService().trackAppOpen();
  }

  void _showLangDialog() {
    final current = context.locale.languageCode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('settings.language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...LocaleStore.supportedCodes.map((code) => ListTile(
              title: Text(ctx.tr('settings.language_$code')),
              leading: Icon(Icons.check_circle, color: current == code ? AppColors.primary : Colors.transparent),
              onTap: () {
                final locale = Locale(code);
                ctx.read<LocaleStore>().setLocale(locale);
                ctx.setLocale(locale);
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }

  Widget _languageButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _showLangDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.public_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                _shortCode(context.locale.languageCode),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
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
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _skipLogin,
                            child: Text(context.tr('auth.skip'), style: TextStyle(color: AppColors.textSecondaryFor(context))),
                          ),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              right: 16,
              child: _languageButton(),
            ),
          ],
        ),
      ),
    );
  }
}