import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/tag.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';

class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key});
  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        final apiTags = store.tags.map((t) => t.name).toSet();
        final opTags = <String>{};
        for (final op in store.operations) {
          for (final t in store.getTagsForOperation(op)) {
            opTags.add(t);
          }
        }
        final allNames = {...apiTags, ...opTags}.toList()..sort();
        final all = allNames.map((n) => Tag(id: n, name: n)).toList();
        final tags = _search.isEmpty
            ? all
            : all.where((t) => t.name.toLowerCase().contains(_search.toLowerCase())).toList();

        return ScreenScaffold(
          title: context.tr('tags.title'),
          showLogo: false,
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddSheet(context, store),
            child: const Icon(Icons.add),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: context.tr('common.search'),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: AppColors.cardFor(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              Expanded(
                child: tags.isEmpty
                    ? Center(child: Text(context.tr('tags.empty'), style: TextStyle(color: AppColors.textSecondaryFor(context))))
                    : ListView(
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
                              onTap: () => _showEditSheet(context, store, t),
                              trailing: IconButton(
                                icon: Icon(Icons.delete_outline, color: AppColors.textSecondaryFor(context), size: 20),
                                onPressed: () => _confirmDelete(context, store, t),
                              ),
                            ),
                          ),
                        )).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditSheet(BuildContext context, FinanceStore store, Tag t) {
    final nameCtrl = TextEditingController(text: t.name);
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
              Text(context.tr('tags.name'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
              const SizedBox(height: 16),
              AppInput(label: context.tr('tags.name'), controller: nameCtrl, hint: context.tr('tags.name_hint')),
              const SizedBox(height: 16),
              AppButton(
                title: context.tr('tags.save'),
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  store.deleteTag(t.id);
                  store.addTag(Tag(id: DateTime.now().microsecondsSinceEpoch.toRadixString(36), name: name));
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
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
              AppInput(label: context.tr('tags.name'), controller: nameCtrl, hint: context.tr('tags.name_hint')),
              const SizedBox(height: 16),
              AppButton(
                title: context.tr('tags.save'),
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  store.addTag(Tag(id: DateTime.now().microsecondsSinceEpoch.toRadixString(36), name: name));
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
