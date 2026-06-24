import 'package:flutter/material.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../theme/theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Профиль',
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(radius: 40, backgroundColor: AppColors.primaryLight, child: Icon(Icons.person, size: 40, color: AppColors.primary)),
          const SizedBox(height: 12),
          Text('Алексей Иванов', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text)),
          Text('demo@easyfinance.ru', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          _info('Дата регистрации', '15 января 2025'),
          _info('Тариф', 'Бесплатный'),
          _info('Синхронизация', 'Google'),
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
