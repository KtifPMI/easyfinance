import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../store/finance_store.dart';
import '../../store/planned_payment_store.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _logout(BuildContext context) {
    context.read<PlannedPaymentStore>().clear();
    final store = context.read<FinanceStore>();
    store.logout();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final user = store.currentUser;
    final name = user?.name ?? context.tr('profile.demo_user');
    final email = user?.email ?? 'demo@easyfinance.ru';
    final regDate = user?.registeredAt != null ? formatDateLong(user!.registeredAt!.toIso8601String()) : '—';
    final plan = user?.isPremium == true ? context.tr('profile.premium') : context.tr('profile.free');
    final syncLabel = user != null ? 'EasyFinance.ru' : context.tr('profile.local_data');

    return ScreenScaffold(
      title: context.tr('profile.title'),
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(radius: 40, backgroundColor: AppColors.primaryLight, child: Icon(Icons.person, size: 40, color: AppColors.primary)),
          const SizedBox(height: 12),
          Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text)),
          Text(email, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          _info(context.tr('profile.reg_date'), regDate),
          _info(context.tr('profile.tariff'), plan),
          _info(context.tr('profile.sync'), syncLabel),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _logout(context),
                style: TextButton.styleFrom(foregroundColor: AppColors.expense),
                child: Text(context.tr('profile.logout')),
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
