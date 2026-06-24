import 'package:flutter/material.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../theme/theme.dart';

class BankScreen extends StatelessWidget {
  const BankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final banks = [
      ('Тинькофф', true, 'connected'),
      ('Сбербанк', true, 'connected'),
      ('Альфа-Банк', false, null),
      ('ВТБ', false, null),
    ];

    return ScreenScaffold(
      title: 'EasyBank',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Подключите банки для автоматической загрузки операций', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ...banks.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              child: Row(
                children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.account_balance, color: AppColors.primary)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(b.$1, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text))),
                  if (b.$2)
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)), child: Text('Подключён', style: TextStyle(fontSize: 11, color: AppColors.success)))
                  else
                    Icon(Icons.add_circle_outline, color: AppColors.primary),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}
