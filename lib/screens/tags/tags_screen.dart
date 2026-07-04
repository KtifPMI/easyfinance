import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';

class TagsScreen extends StatelessWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        final tags = store.tags;
        return ScreenScaffold(
          title: context.tr('tags.title'),
          child: tags.isEmpty
              ? Center(child: Text(context.tr('tags.empty'), style: TextStyle(color: AppColors.textSecondaryFor(context))))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tags.length,
                  itemBuilder: (context, index) {
                    final t = tags[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            child: Icon(Icons.label, color: AppColors.primary, size: 20),
                          ),
                          title: Text(t.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                          subtitle: Text('#${t.name}', style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
