import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../components/common/screen_scaffold.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../models/tag.dart';

class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key});
  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FinanceStore>().refreshTags();
    });
  }

  Future<void> _showAddSheet(BuildContext context, FinanceStore store) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('tags.add_title')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.tr('tags.name_hint'),
            filled: true,
            fillColor: AppColors.cardFor(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('budget.cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(context.tr('common.add'))),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && mounted) {
      await store.addTag(Tag(id: '', name: name));
    }
  }

  Future<void> _confirmDelete(BuildContext context, FinanceStore store, Tag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('tags.delete_title')),
        content: Text(context.tr('tags.confirm_delete')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('budget.cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('common.delete'), style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await store.deleteTag(tag.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        // Same sources as the operations filter: tag names parsed directly from
        // operations, merged with the server catalog (tags.get).
        final catalog = store.tags;
        final byName = <String, Tag>{};
        for (final t in catalog) {
          byName[t.name.toLowerCase()] = t;
        }
        for (final op in store.operations) {
          for (final name in store.getTagsForOperation(op)) {
            final key = name.toLowerCase();
            byName.putIfAbsent(key, () => Tag(id: '', name: name));
          }
        }
        final tags = _search.isEmpty
            ? byName.values.toList()
            : byName.values.where((t) => t.name.toLowerCase().contains(_search.toLowerCase())).toList();
        tags.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        return ScreenScaffold(
          title: context.tr('tags.title'),
          showLogo: false,
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
              if (tags.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Center(child: Text(context.tr('tags.empty'), style: TextStyle(color: AppColors.textSecondaryFor(context)))),
                )
              else
                Column(
                  children: tags.map((tag) => Padding(
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
                        title: Text('#${tag.name}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textFor(context))),
                        trailing: tag.id.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.delete_outline, color: AppColors.expense, size: 20),
                                onPressed: () => _confirmDelete(context, store, tag),
                              )
                            : null,
                      ),
                    ),
                  )).toList(),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddSheet(context, store),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }
}
