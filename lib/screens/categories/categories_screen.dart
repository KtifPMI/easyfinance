import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../components/common/app_card.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/category.dart' as cat;
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/category_icons.dart';
import '../../utils/translate_category.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        final incomes = store.categories.where((c) => c.type == 'income').toList();
        final expenses = store.categories.where((c) => c.type == 'expense').toList();

        return ScreenScaffold(
          title: context.tr('categories.title'),
          showLogo: false,
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddSheet(context, store),
            child: const Icon(Icons.add),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (incomes.isNotEmpty) ...[
                _sectionHeader(context, context.tr('categories.incomes')),
                const SizedBox(height: 8),
                ..._buildGrouped(context, store, incomes),
                const SizedBox(height: 16),
              ],
              if (expenses.isNotEmpty) ...[
                _sectionHeader(context, context.tr('categories.expenses')),
                const SizedBox(height: 8),
                ..._buildGrouped(context, store, expenses),
              ],
              if (incomes.isEmpty && expenses.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(context.tr('categories.no_categories'), style: TextStyle(color: AppColors.textSecondaryFor(context))),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondaryFor(context))),
    );
  }

  List<Widget> _buildGrouped(BuildContext context, FinanceStore store, List<cat.Category> cats) {
    final grouped = <String?, List<cat.Category>>{};
    for (final c in cats) {
      final root = _rootName(c, store.categories);
      (grouped[root] ??= []).add(c);
    }
    // Sort groups: system categories first, then custom
    final entries = grouped.entries.toList();
    entries.sort((a, b) {
      final aSys = a.value.any((c) => c.isDefault);
      final bSys = b.value.any((c) => c.isDefault);
      if (aSys && !bSys) return -1;
      if (!aSys && bSys) return 1;
      return (a.key ?? '').compareTo(b.key ?? '');
    });

    final result = <Widget>[];
    for (final entry in entries) {
      if (entry.key != null && entry.key!.isNotEmpty) {
        result.add(_groupLabel(context, entry.key!));
      }
      for (final c in entry.value) {
        result.add(_categoryTile(context, store, c));
      }
    }
    return result;
  }

  String? _rootName(cat.Category c, List<cat.Category> all) {
    cat.Category? current = c;
    final seen = <String>{};
    while (current?.parentId != null && current!.parentId!.isNotEmpty) {
      if (!seen.add(current.id)) break;
      current = all.where((p) => p.id == current!.parentId).firstOrNull;
    }
    return current != null && current.parentId == null ? current.name : null;
  }

  Widget _groupLabel(BuildContext context, String name) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
      child: Text(
        tCat(context, name),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondaryFor(context)),
      ),
    );
  }

  Widget _categoryTile(BuildContext context, FinanceStore store, cat.Category c) {
    final icon = categoryIconFor(c, allCategories: store.categories);
    final color = _parseColor(c.color);
    final isSystem = c.isDefault;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: InkWell(
          onTap: isSystem ? null : () => _showEditSheet(context, store, c),
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tCat(context, c.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textFor(context))),
                    if (isSystem)
                      Text(context.tr('categories.system'), style: TextStyle(fontSize: 11, color: AppColors.textSecondaryFor(context))),
                  ],
                ),
              ),
              if (!isSystem)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _showEditSheet(context, store, c),
                      child: Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondaryFor(context)),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _confirmDelete(context, store, c),
                      child: Icon(Icons.delete_outline, size: 18, color: AppColors.textSecondaryFor(context)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, FinanceStore store, cat.Category c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('categories.confirm_delete')),
        content: Text(tCat(context, c.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('categories.cancel'))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              store.deleteCategory(c.id);
            },
            child: Text(context.tr('categories.delete'), style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context, FinanceStore store) {
    final nameCtrl = TextEditingController();
    var type = 'expense';
    String? parentId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.tr('categories.new'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                const SizedBox(height: 16),
                AppInput(label: context.tr('categories.name'), controller: nameCtrl),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: InputDecoration(
                    labelText: context.tr('categories.type'),
                    filled: true, fillColor: AppColors.cardFor(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  items: [
                    DropdownMenuItem(value: 'expense', child: Text(context.tr('categories.type_expense'))),
                    DropdownMenuItem(value: 'income', child: Text(context.tr('categories.type_income'))),
                  ],
                  onChanged: (v) => setInner(() => type = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: parentId,
                  decoration: InputDecoration(
                    labelText: context.tr('categories.parent'),
                    filled: true, fillColor: AppColors.cardFor(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text(context.tr('categories.no_parent'))),
                    ...store.categories.where((c) => c.type == type && c.isDefault).map((c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(tCat(context, c.name), overflow: TextOverflow.ellipsis),
                    )),
                  ],
                  onChanged: (v) => setInner(() => parentId = v),
                ),
                const SizedBox(height: 16),
                AppButton(
                  title: context.tr('categories.save'),
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final icon = type == 'income' ? 'income' : 'other';
                    store.addCategory(cat.Category(
                      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
                      name: name,
                      type: type,
                      icon: icon,
                      color: type == 'income' ? '#16A34A' : '#6B7280',
                      parentId: parentId,
                      isDefault: false,
                    ));
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, FinanceStore store, cat.Category c) {
    final nameCtrl = TextEditingController(text: c.name);
    var type = c.type;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.tr('categories.edit'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                const SizedBox(height: 16),
                AppInput(label: context.tr('categories.name'), controller: nameCtrl),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: InputDecoration(
                    labelText: context.tr('categories.type'),
                    filled: true, fillColor: AppColors.cardFor(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  items: [
                    DropdownMenuItem(value: 'expense', child: Text(context.tr('categories.type_expense'))),
                    DropdownMenuItem(value: 'income', child: Text(context.tr('categories.type_income'))),
                  ],
                  onChanged: (v) => setInner(() => type = v!),
                ),
                const SizedBox(height: 16),
                AppButton(
                  title: context.tr('categories.save'),
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    store.updateCategory(cat.Category(
                      id: c.id,
                      name: name,
                      type: type,
                      icon: c.icon,
                      color: c.color,
                      parentId: c.parentId,
                      isDefault: false,
                    ));
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
