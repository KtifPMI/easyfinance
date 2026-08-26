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
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TagDeleteDialog(tag: tag, store: store),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        // Same sources as the operations filter, exposed via store.allTags
        // (already excludes server-side soft-deleted tags).
        final tags = _search.isEmpty
            ? store.allTags
            : store.allTags.where((t) => t.name.toLowerCase().contains(_search.toLowerCase())).toList();

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
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: AppColors.expense, size: 20),
                          onPressed: () => _confirmDelete(context, store, tag),
                        ),
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

class _TagDeleteDialog extends StatefulWidget {
  final Tag tag;
  final FinanceStore store;
  const _TagDeleteDialog({required this.tag, required this.store});

  @override
  State<_TagDeleteDialog> createState() => _TagDeleteDialogState();
}

class _TagDeleteDialogState extends State<_TagDeleteDialog> {
  String? _replacement;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final tag = widget.tag;
    final hasOps = store.operationsUsingTag(tag.name).isNotEmpty;
    final replacements = store.allTags.where((t) => t.name.toLowerCase() != tag.name.toLowerCase()).toList();
    final message = hasOps
        ? 'tags.confirm_delete_with_ops'.tr(args: [tag.name])
        : 'tags.confirm_delete'.tr(args: [tag.name]);

    return AlertDialog(
      title: Text('tags.delete_title'.tr()),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Text('tags.replace_with'.tr(), style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: _replacement,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.cardFor(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              hint: Text('tags.replace_none'.tr()),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text('tags.replace_none'.tr())),
                ...replacements.map((t) => DropdownMenuItem<String?>(value: t.name, child: Text('#${t.name}'))),
              ],
              onChanged: (v) => setState(() => _replacement = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('budget.cancel'.tr())),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            store.deleteTag(tag, replacementTagName: _replacement);
          },
          child: Text('common.delete'.tr(), style: TextStyle(color: AppColors.expense)),
        ),
      ],
    );
  }
}
