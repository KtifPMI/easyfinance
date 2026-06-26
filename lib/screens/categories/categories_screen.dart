import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import 'add_category_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        return ScreenScaffold(
          title: 'Категории',
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddCategoryScreen())),
            ),
          ],
          child: Column(
            children: [
              Text('Доходы', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 8),
              ...store.categories.where((c) => c.type == 'income').map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: AppCard(
                  child: InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddCategoryScreen(categoryId: c.id))),
                    child: Row(
                      children: [
                        Container(width: 36, height: 36, decoration: BoxDecoration(color: _parseColor(c.color).withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(Icons.arrow_downward, size: 16, color: _parseColor(c.color))),
                        const SizedBox(width: 12),
                        Text(c.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                        const Spacer(),
                        if (!c.isDefault) Icon(Icons.delete_outline, size: 18, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              )),
              const SizedBox(height: 16),
              Text('Расходы', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 8),
              ...store.categories.where((c) => c.type == 'expense').map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: AppCard(
                  child: InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddCategoryScreen(categoryId: c.id))),
                    child: Row(
                      children: [
                        Container(width: 36, height: 36, decoration: BoxDecoration(color: _parseColor(c.color).withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(Icons.arrow_upward, size: 16, color: _parseColor(c.color))),
                        const SizedBox(width: 12),
                        Text(c.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                        const Spacer(),
                        if (!c.isDefault) Icon(Icons.delete_outline, size: 18, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
