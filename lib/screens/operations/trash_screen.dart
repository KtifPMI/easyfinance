import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/screen_scaffold.dart';
import '../../theme/theme.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: context.tr('operations.trash'),
      child: Center(child: Text(context.tr('operations.trash_empty'), style: TextStyle(color: AppColors.textSecondary))),
    );
  }
}
