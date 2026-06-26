import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _logout(BuildContext context) {
    final store = context.read<FinanceStore>();
    store.logout();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final user = store.currentUser;
    final name = user?.name ?? 'Демо-пользователь';
    final email = user?.email ?? 'demo@easyfinance.ru';
    final regDate = user?.registeredAt != null ? formatDateLong(user!.registeredAt!.toIso8601String()) : '—';
    final plan = user?.isPremium == true ? 'Премиум' : 'Бесплатный';
    final syncLabel = user != null ? 'EasyFinance.ru' : 'Локальные данные';

    return ScreenScaffold(
      title: 'Профиль',
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(radius: 40, backgroundColor: AppColors.primaryLight, child: Icon(Icons.person, size: 40, color: AppColors.primary)),
          const SizedBox(height: 12),
          Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text)),
          Text(email, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          _info('Дата регистрации', regDate),
          _info('Тариф', plan),
          _info('Синхронизация', syncLabel),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _logout(context),
                style: TextButton.styleFrom(foregroundColor: AppColors.expense),
                child: const Text('Выйти из аккаунта'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
          ],
        ),
      ),
    );
  }
}
