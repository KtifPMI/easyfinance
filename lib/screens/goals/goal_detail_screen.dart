import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/screen_scaffold.dart';

class GoalDetailScreen extends StatelessWidget {
  const GoalDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(title: context.tr('goals.title'), child: Text(context.tr('goals.detail')));
  }
}
