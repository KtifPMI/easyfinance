import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/screen_scaffold.dart';
import '../../theme/theme.dart';

class InformerScreen extends StatelessWidget {
  const InformerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: context.tr('informer.title'),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: AppColors.textSecondaryFor(context)),
            const SizedBox(height: 16),
            Text(context.tr('informer.subtitle'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
            const SizedBox(height: 8),
            Text(context.tr('informer.description'), style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context)), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
