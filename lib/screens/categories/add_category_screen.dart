import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/category.dart' as cat;
import '../../store/finance_store.dart';
import '../../theme/theme.dart';

class AddCategoryScreen extends StatefulWidget {
  final String? categoryId;
  const AddCategoryScreen({super.key, this.categoryId});

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final _nameCtrl = TextEditingController();
  String _type = 'expense';

  bool get _isEditing => widget.categoryId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
    }
  }

  void _loadExisting() {
    final store = context.read<FinanceStore>();
    final c = store.categories.where((c) => c.id == widget.categoryId).firstOrNull;
    if (c == null) return;
    _nameCtrl.text = c.name;
    _type = c.type;
    setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final store = context.read<FinanceStore>();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final category = cat.Category(
      id: _isEditing ? widget.categoryId! : DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name: name,
      type: _type,
      icon: 'other_$_type',
      color: _type == 'income' ? '#16A34A' : '#6B7280',
      isDefault: false,
    );

    if (_isEditing) {
      store.updateCategory(category);
    } else {
      store.addCategory(category);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: _isEditing ? 'Редактировать категорию' : 'Новая категория',
      child: Column(
        children: [
          AppInput(label: 'Название', controller: _nameCtrl),
          const SizedBox(height: 16),
          Text('Тип', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: InputDecoration(
              filled: true, fillColor: AppColors.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: const [
              DropdownMenuItem(value: 'income', child: Text('Доход')),
              DropdownMenuItem(value: 'expense', child: Text('Расход')),
            ],
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 24),
          AppButton(title: 'Сохранить', onPressed: _save),
        ],
      ),
    );
  }
}
