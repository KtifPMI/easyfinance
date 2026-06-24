import 'package:flutter/material.dart';
import '../../components/common/screen_scaffold.dart';
import '../../theme/theme.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenScaffold(
      title: 'Корзина',
      child: Center(child: Text('Корзина пуста', style: TextStyle(color: AppColors.textSecondary))),
    );
  }
}
