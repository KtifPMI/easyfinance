import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/screen_scaffold.dart';

class BudgetDetailScreen extends StatelessWidget {
  const BudgetDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(title: context.tr('budget.budget'), child: Text(context.tr('budget.detail')));
  }
}
