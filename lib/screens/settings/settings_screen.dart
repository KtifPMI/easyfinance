import 'package:flutter/material.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../theme/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Настройки',
      child: Column(
        children: [
          _item('Валюта', 'Российский рубль (₽)'),
          _item('Язык', 'Русский'),
          _item('Тарифный план', 'Бесплатный'),
          _item('Уведомления', 'Включены'),
          _divider(),
          _item('О приложении', 'v1.0.0'),
          _item('Оценить приложение', ''),
          _item('Помощь', ''),
        ],
      ),
    );
  }

  Widget _item(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 15, color: AppColors.text)),
            if (value.isNotEmpty) Text(value, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1));
}
