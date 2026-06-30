import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/app_input.dart';
import '../../components/common/screen_scaffold.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';

class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key});

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _addTag(FinanceStore store) {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    store.addTag(name);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        return ScreenScaffold(
          title: context.tr('tags.title'),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: AppInput(
                    label: context.tr('tags.name'),
                    controller: _ctrl,
                    onSubmitted: (_) => _addTag(store),
                  )),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.add_circle, color: AppColors.primary, size: 32),
                    onPressed: () => _addTag(store),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (store.tags.isEmpty)
                Expanded(child: Center(child: Text(context.tr('tags.empty'), style: TextStyle(color: AppColors.textSecondary))))
              else
                Expanded(
                  child: ListView(
                    children: store.tags.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: AppCard(
                        child: Row(
                          children: [
                            Icon(Icons.label_outline, color: AppColors.primary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(t.name, style: TextStyle(fontSize: 15, color: AppColors.text))),
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(context.tr('tags.confirm_delete')),
                                    content: Text(t.name),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('tags.cancel'))),
                                      TextButton(
                                        onPressed: () {
                                          store.deleteTag(t.id);
                                          Navigator.pop(ctx);
                                        },
                                        child: Text(context.tr('tags.delete'), style: TextStyle(color: AppColors.danger)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Icon(Icons.delete_outline, size: 18, color: AppColors.textSecondary),
                            ),
                          ],
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
}
