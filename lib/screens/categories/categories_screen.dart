import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../components/common/app_card.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/category.dart' as cat;
import '../../models/operation.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/category_icons.dart';
import '../../utils/translate_category.dart';
import '../../utils/system_categories.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _search = '';
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        final allIncomes = store.categories.where((c) => c.type == 'income').toList();
        final allExpenses = store.categories.where((c) => c.type == 'expense').toList();
        final incomes = _search.isEmpty
            ? allIncomes
            : allIncomes.where((c) => c.name.toLowerCase().contains(_search.toLowerCase())).toList();
        final expenses = _search.isEmpty
            ? allExpenses
            : allExpenses.where((c) => c.name.toLowerCase().contains(_search.toLowerCase())).toList();

        return ScreenScaffold(
          title: context.tr('categories.title'),
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
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.cardFor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondaryFor(context),
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: [
                    Tab(text: context.tr('categories.incomes')),
                    Tab(text: context.tr('categories.expenses')),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    incomes.isEmpty
                        ? Center(child: Text(context.tr('categories.no_categories'), style: TextStyle(color: AppColors.textSecondaryFor(context))))
                        : SingleChildScrollView(child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(children: _buildTwoLevel(context, store, 'income')),
                          )),
                    expenses.isEmpty
                        ? Center(child: Text(context.tr('categories.no_categories'), style: TextStyle(color: AppColors.textSecondaryFor(context))))
                        : SingleChildScrollView(child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(children: _buildTwoLevel(context, store, 'expense')),
                          )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildTwoLevel(BuildContext context, FinanceStore store, String type) {
    final all = store.categories.where((c) => c.type == type).toList();
    final allIds = all.map((c) => c.id).toSet();
    final childMap = <String, List<cat.Category>>{};
    for (final c in all) {
      if (c.parentId != null && c.parentId!.isNotEmpty) {
        (childMap[c.parentId!] ??= []).add(c);
      }
    }
    final roots = all.where((c) => c.parentId == null || c.parentId!.isEmpty || !allIds.contains(c.parentId!)).toList();
    roots.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return _buildTree(context, store, roots, 0, childMap);
  }

  List<Widget> _buildTree(BuildContext context, FinanceStore store, List<cat.Category> nodes, int depth, Map<String, List<cat.Category>> childMap) {
    final result = <Widget>[];
    for (final node in nodes) {
      final kids = (childMap[node.id] ?? [])..sort((a, b) => a.name.compareTo(b.name));
      if (kids.isNotEmpty) {
        result.add(_parentHeader(context, store, node, kids.length, depth));
        if (_expanded.contains(node.id)) {
          result.addAll(_buildTree(context, store, kids, depth + 1, childMap));
        }
      } else {
        result.add(_categoryTile(context, store, node, indent: depth > 0));
      }
    }
    return result;
  }

  Widget _parentHeader(BuildContext context, FinanceStore store, cat.Category p, int childCount, int depth) {
    final icon = categoryIconFor(p, allCategories: store.categories);
    final color = p.type == 'income' ? AppColors.income : AppColors.expense;
    final expanded = _expanded.contains(p.id);
    return Padding(
      padding: EdgeInsets.only(bottom: 6, left: depth * 12.0),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: InkWell(
          onTap: () => setState(() {
            if (expanded) _expanded.remove(p.id);
            else _expanded.add(p.id);
          }),
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
                    Text(tCat(context, p.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textFor(context))),
                    if (p.isDefault)
                      Text(context.tr('categories.system'), style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                  ],
                ),
              ),
              if (childCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text('$childCount', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                ),
              Icon(expanded ? Icons.expand_less : Icons.chevron_right, color: AppColors.textSecondaryFor(context)),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _showEditSheet(context, store, p),
                child: Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondaryFor(context)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _confirmDelete(context, store, p),
                child: Icon(Icons.delete_outline, size: 18, color: AppColors.textSecondaryFor(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryTile(BuildContext context, FinanceStore store, cat.Category c, {bool indent = false}) {
    final icon = categoryIconFor(c, allCategories: store.categories);
    final color = c.type == 'income' ? AppColors.income : AppColors.expense;
    final isSystem = c.isDefault;

    return Padding(
      padding: EdgeInsets.only(bottom: 6, left: indent ? 24 : 0),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: InkWell(
          onTap: () => _showEditSheet(context, store, c),
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
                    Text(tCat(context, c.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                    if (isSystem)
                      Text(context.tr('categories.system'), style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                  ],
                ),
              ),
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
    final ops = store.operations.where((o) => o.categoryId == c.id).toList();
    if (ops.isEmpty) {
      _showSimpleDeleteConfirm(context, store, c);
    } else {
      _showReassignDelete(context, store, c, ops);
    }
  }

  void _showSimpleDeleteConfirm(BuildContext context, FinanceStore store, cat.Category c) {
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

  void _showReassignDelete(BuildContext context, FinanceStore store, cat.Category c, List<Operation> ops) {
    String? replacementId;
    final candidates = store.categories.where((x) => x.type == c.type && x.id != c.id).toList();
    final canDelete = candidates.isEmpty;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(context.tr('categories.delete_with_ops_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('categories.delete_with_ops', namedArgs: {'count': ops.length.toString()})),
              const SizedBox(height: 12),
              if (candidates.isEmpty)
                Text(context.tr('categories.no_replacement'), style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context)))
              else
                DropdownButtonFormField<String>(
                  decoration: _ddDecoration(context, context.tr('categories.replacement_category')),
                  value: replacementId,
                  items: candidates.map((x) => DropdownMenuItem<String>(
                    value: x.id,
                    child: Text(tCat(context, x.name), overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (v) => setD(() => replacementId = v),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('categories.cancel'))),
            TextButton(
              onPressed: (replacementId != null || canDelete)
                  ? () async {
                      Navigator.pop(ctx);
                      if (replacementId != null) {
                        for (final op in ops) {
                          await store.updateOperation(op.copyWith(categoryId: replacementId));
                        }
                      }
                      store.deleteCategory(c.id);
                    }
                  : null,
              child: Text(
                context.tr('categories.delete'),
                style: TextStyle(color: (replacementId != null || canDelete) ? AppColors.expense : AppColors.textSecondaryFor(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, FinanceStore store) {
    final nameCtrl = TextEditingController();
    var type = 'expense';
    String? parentId;
    String? systemId;
    CategoryIconOption? selectedIcon;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) {
          selectedIcon ??= kDefaultCategoryIcons.firstWhere(
            (o) => o.logical == (type == 'income' ? 'other_income' : 'other_expense'),
            orElse: () => kDefaultCategoryIcons.first,
          );
          final parent = parentId != null ? store.categories.where((p) => p.id == parentId).firstOrNull : null;
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.tr('categories.new'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                  const SizedBox(height: 16),
                  AppInput(label: context.tr('categories.name'), controller: nameCtrl),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: _ddDecoration(context, context.tr('categories.type')),
                    items: [
                      DropdownMenuItem(value: 'expense', child: Text(context.tr('categories.type_expense'))),
                      DropdownMenuItem(value: 'income', child: Text(context.tr('categories.type_income'))),
                    ],
                    onChanged: (v) => setInner(() {
                      type = v!;
                      systemId = null;
                      selectedIcon = kDefaultCategoryIcons.firstWhere(
                        (o) => o.logical == (type == 'income' ? 'other_income' : 'other_expense'),
                        orElse: () => kDefaultCategoryIcons.first,
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: parentId,
                    decoration: _ddDecoration(context, context.tr('categories.parent')),
                    items: [
                      DropdownMenuItem<String?>(value: null, child: Text(context.tr('categories.no_parent'))),
                      ...store.categories.where((c) => c.type == type && c.isDefault).map((c) => DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(tCat(context, c.name), overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: (v) => setInner(() => parentId = v),
                  ),
                  const SizedBox(height: 12),
                  if (parentId == null)
                    _systemCategoryField(ctx, type, systemId, (v) => setInner(() => systemId = v))
                  else
                    _inheritedSystemField(ctx, store, parent),
                  const SizedBox(height: 16),
                  _iconPicker(ctx, selectedIcon, (opt) => setInner(() => selectedIcon = opt)),
                  const SizedBox(height: 16),
                  AppButton(
                    title: context.tr('categories.save'),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty || selectedIcon == null) return;
                      if (parentId == null && (systemId == null || systemId!.isEmpty)) return;
                      final effectiveSystemId = parentId == null
                          ? systemId
                          : store.categories.where((p) => p.id == parentId).firstOrNull?.systemId;
                      store.addCategory(cat.Category(
                        id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
                        name: name,
                        type: type,
                        icon: selectedIcon!.logical,
                        color: selectedIcon!.color,
                        parentId: parentId,
                        isDefault: false,
                        systemId: effectiveSystemId,
                      ));
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  InputDecoration _ddDecoration(BuildContext context, String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.cardFor(context),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  Widget _systemCategoryField(BuildContext context, String type, String? systemId, ValueChanged<String?> onChanged) {
    final map = systemCategories[type] ?? const <int, String>{};
    return DropdownButtonFormField<String?>(
      initialValue: systemId,
      decoration: _ddDecoration(context, context.tr('categories.system_category')),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(context.tr('categories.choose_system'))),
        ...map.entries.map((e) => DropdownMenuItem<String?>(value: e.key.toString(), child: Text(e.value, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: onChanged,
    );
  }

  Widget _inheritedSystemField(BuildContext context, FinanceStore store, cat.Category? parent) {
    final inheritedName = (parent != null && parent.systemId != null && parent.systemId!.isNotEmpty)
        ? (systemCategories[parent.type]?[int.tryParse(parent.systemId!)] ?? context.tr('categories.system_inherited'))
        : context.tr('categories.system_inherited');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardFor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('categories.system_category'), style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
          const SizedBox(height: 4),
          Text('${context.tr('categories.system_inherited')}: $inheritedName', style: TextStyle(fontSize: 15, color: AppColors.textFor(context))),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, FinanceStore store, cat.Category c) {
    final nameCtrl = TextEditingController(text: c.name);
    var type = c.type;
    String? parentId = c.parentId;
    String? systemId = c.systemId;
    final initial = kDefaultCategoryIcons.where((o) => o.logical == c.icon).firstOrNull
        ?? kDefaultCategoryIcons.where((o) => o.catimg == _storeIconToCatimg(c.icon)).firstOrNull
        ?? kDefaultCategoryIcons.first;
    var selectedIcon = initial;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) {
          final parentCats = store.categories.where((c2) => c2.type == type && c2.isDefault).toList();
          if (parentId != null && !parentCats.any((x) => x.id == parentId)) {
            final cur = store.categories.where((x) => x.id == parentId).firstOrNull;
            if (cur != null) parentCats.add(cur);
          }
          final parent = parentId != null ? store.categories.where((p) => p.id == parentId).firstOrNull : null;
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.tr('categories.edit'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                  const SizedBox(height: 16),
                  AppInput(label: context.tr('categories.name'), controller: nameCtrl),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: _ddDecoration(context, context.tr('categories.type')),
                    items: [
                      DropdownMenuItem(value: 'expense', child: Text(context.tr('categories.type_expense'))),
                      DropdownMenuItem(value: 'income', child: Text(context.tr('categories.type_income'))),
                    ],
                    onChanged: (v) => setInner(() {
                      type = v!;
                      parentId = null;
                      systemId = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: parentId,
                    decoration: _ddDecoration(context, context.tr('categories.parent')),
                    items: [
                      DropdownMenuItem<String?>(value: null, child: Text(context.tr('categories.no_parent'))),
                      ...parentCats.map((c2) => DropdownMenuItem<String?>(
                        value: c2.id,
                        child: Text(tCat(context, c2.name), overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: (v) => setInner(() => parentId = v),
                  ),
                  const SizedBox(height: 12),
                  if (parentId == null)
                    _systemCategoryField(ctx, type, systemId, (v) => setInner(() => systemId = v))
                  else
                    _inheritedSystemField(ctx, store, parent),
                  const SizedBox(height: 16),
                  _iconPicker(ctx, selectedIcon, (opt) => setInner(() => selectedIcon = opt)),
                  const SizedBox(height: 16),
                  AppButton(
                    title: context.tr('categories.save'),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      if (parentId == null && (systemId == null || systemId!.isEmpty)) return;
                      final effectiveSystemId = parentId == null
                          ? systemId
                          : store.categories.where((p) => p.id == parentId).firstOrNull?.systemId;
                      store.updateCategory(cat.Category(
                        id: c.id,
                        name: name,
                        type: type,
                        icon: selectedIcon.logical,
                        color: selectedIcon.color,
                        parentId: parentId,
                        isDefault: c.isDefault,
                        systemId: effectiveSystemId,
                      ));
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _storeIconToCatimg(String logical) {
    const map = <String, String>{
      'food': 'catimg1', 'transport': 'catimg2', 'housing': 'catimg3', 'shopping': 'catimg4',
      'health': 'catimg5', 'entertainment': 'catimg6', 'education': 'catimg7', 'travel': 'catimg8',
      'salary': 'catimg9', 'freelance': 'catimg10', 'business': 'catimg11', 'gift': 'catimg12',
      'car': 'catimg13', 'sports': 'catimg14', 'dining': 'catimg15', 'utilities': 'catimg16',
      'internet': 'catimg17', 'clothing': 'catimg18', 'children': 'catimg19', 'pets': 'catimg20',
      'taxes': 'catimg21', 'insurance': 'catimg22', 'invest': 'catimg23', 'rent': 'catimg24',
      'other_income': 'catimg25', 'other_expense': 'catimg26',
    };
    return map[logical] ?? 'catimg26';
  }

  Widget _iconPicker(BuildContext context, CategoryIconOption? selected, ValueChanged<CategoryIconOption> onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.tr('categories.icon'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondaryFor(context))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kDefaultCategoryIcons.map((o) {
            final isSel = selected?.catimg == o.catimg;
            final color = _colorFromHex(o.color);
            return GestureDetector(
              onTap: () => onPick(o),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSel ? color.withValues(alpha: 0.18) : AppColors.cardFor(context),
                  border: isSel ? Border.all(color: color, width: 2) : Border.all(color: AppColors.textSecondaryFor(context).withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(o.icon, size: 22, color: color),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _colorFromHex(String hex) {
    final h = hex.replaceFirst('#', '');
    final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
    return v != null ? Color(v) : AppColors.textSecondaryFor(context);
  }
}
