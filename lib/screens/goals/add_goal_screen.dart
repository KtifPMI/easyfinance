import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/goal.dart';
import '../../store/finance_store.dart';

class AddGoalScreen extends StatefulWidget {
  const AddGoalScreen({super.key});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  final _titleCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _currentCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _targetCtrl.dispose();
    _currentCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final store = context.read<FinanceStore>();
    final target = double.tryParse(_targetCtrl.text.replaceAll(',', '.')) ?? 0;
    final current = double.tryParse(_currentCtrl.text.replaceAll(',', '.')) ?? 0;
    if (target <= 0 || _titleCtrl.text.isEmpty) return;

    final future = DateTime.now().add(const Duration(days: 365));
    store.addGoal(Goal(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      title: _titleCtrl.text,
      targetAmount: target,
      currentAmount: current,
      deadline: future.toIso8601String().substring(0, 10),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: context.tr('goals.new'),
      child: Column(
        children: [
          AppInput(label: context.tr('goals.name'), controller: _titleCtrl),
          const SizedBox(height: 16),
          AppInput(label: context.tr('goals.target_amount'), controller: _targetCtrl, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          AppInput(label: context.tr('goals.current_amount'), controller: _currentCtrl, keyboardType: TextInputType.number),
          const SizedBox(height: 24),
          AppButton(title: context.tr('goals.save'), onPressed: _save),
        ],
      ),
    );
  }
}
