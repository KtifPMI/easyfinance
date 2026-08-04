import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/tag.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';

class TagsScreen extends StatelessWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        final tags = store.tags.toList()..sort((a, b) => a.name.compareTo(b.name));

        return ScreenScaffold(
          title: context.tr('tags.title'),
          showLogo: false,
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddSheet(context, store),
            child: const Icon(Icons.add),
          ),
          child: tags.isEmpty
              ? Center(
                  child: Text(
                    context.tr('tags.empty'),
                    style: TextStyle(color: AppColors.textSecondaryFor(context)),
                  ),
                )
              : Column(
                  children: tags.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardFor(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                          child: Icon(Icons.label, color: AppColors.primary, size: 20),
                        ),
                        title: Text('#${t.name}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textFor(context))),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: AppColors.textSecondaryFor(context), size: 20),
                          onPressed: () => _confirmDelete(context, store, t),
                        ),
                      ),
                    ),
                  )).toList(),
                ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, FinanceStore store, Tag t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('tags.confirm_delete')),
        content: Text('#${t.name}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('tags.cancel'))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              store.deleteTag(t.id);
            },
            child: Text(context.tr('tags.delete'), style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context, FinanceStore store) {
    final nameCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.tr('tags.new'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
              const SizedBox(height: 16),
              AppInput(
                label: context.tr('tags.name'),
                controller: nameCtrl,
                hint: context.tr('tags.name_hint'),
                onSubmitted: (_) => _addAndClose(ctx, store, nameCtrl),
              ),
              const SizedBox(height: 16),
              AppButton(
                title: context.tr('tags.save'),
                onPressed: () => _addAndClose(ctx, store, nameCtrl),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _addAndClose(BuildContext ctx, FinanceStore store, TextEditingController ctrl) {
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    store.addTag(Tag(id: DateTime.now().microsecondsSinceEpoch.toRadixString(36), name: name));
    Navigator.pop(ctx);
  }
}
