import 'package:flutter/material.dart';
import '../../components/common/screen_scaffold.dart';
import '../../theme/theme.dart';

class InformerScreen extends StatelessWidget {
  const InformerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Информер',
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text('Виджеты быстрого доступа', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(height: 8),
            Text('Настройте отображение финансовой информации на главном экране', style: TextStyle(fontSize: 13, color: AppColors.textSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
