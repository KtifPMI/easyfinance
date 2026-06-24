import 'package:flutter/material.dart';
import '../../components/common/screen_scaffold.dart';

class BudgetDetailScreen extends StatelessWidget {
  const BudgetDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenScaffold(title: 'Бюджет', child: Text('Детали бюджета'));
  }
}
