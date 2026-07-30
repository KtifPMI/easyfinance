import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../components/common/app_button.dart';
import '../../services/notification_service.dart';
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
    final prefs = await SharedPreferences.getInstance();
    final hasPin = prefs.getString('easyfinance_pin')?.isNotEmpty ?? false;
    final startScreen = prefs.getString('easyfinance_start_screen') ?? 'main';
    final initialRoute = hasPin ? '/pin' : (startScreen == 'addOperation' ? '/add-operation' : '/main');

    if (restored && mounted) {
      Navigator.pushReplacementNamed(context, initialRoute);
      await store.fetchAllData();
      NotificationService().rescheduleAll();
      NotificationService().trackAppOpen();
    } else if (mounted && !store.useMock) {
      Navigator.pushReplacementNamed(context, initialRoute);
    }
  }

  void _startOAuth() async {
    final result = await Navigator.pushNamed(context, '/oauth');
    if (result == true && mounted) {
      Navigator.pushReplacementNamed(context, '/main');
      NotificationService().trackAppOpen();
    }
  }

  void _skipLogin() {
    Navigator.pushReplacementNamed(context, '/main');
    NotificationService().trackAppOpen();
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
              Text('EasyFinance', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textFor(context))),
              const SizedBox(height: 8),
              Text(context.tr('auth.subtitle'), style: TextStyle(fontSize: 15, color: AppColors.textSecondaryFor(context))),
              const SizedBox(height: 40),
              Text(
                context.tr('auth.description'),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondaryFor(context), fontSize: 14),
              ),
              const Spacer(),
              AppButton(
                title: context.tr('auth.login'),
                onPressed: _startOAuth,
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
                onPressed: _skipLogin,
                child: Text(context.tr('auth.skip'), style: TextStyle(color: AppColors.textSecondaryFor(context))),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
