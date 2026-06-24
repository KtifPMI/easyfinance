import 'package:flutter/material.dart';
import '../../components/common/screen_scaffold.dart';

class GoalDetailScreen extends StatelessWidget {
  const GoalDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenScaffold(title: 'Цель', child: Text('Детали цели'));
  }
}
