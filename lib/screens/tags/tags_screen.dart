import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../components/common/screen_scaffold.dart';
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
        // Tags are sourced locally from operations only (no API fetch),
        // mirroring the behaviour of the operations filter.
        final tagSet = <String>{};
        for (final op in store.operations) {
          for (final t in store.getTagsForOperation(op)) {
            tagSet.add(t);
          }
        }
        final all = tagSet.toList()..sort();
        final tags = _search.isEmpty
            ? all
            : all.where((t) => t.toLowerCase().contains(_search.toLowerCase())).toList();

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
              Expanded(
                child: tags.isEmpty
                    ? Center(child: Text(context.tr('tags.empty'), style: TextStyle(color: AppColors.textSecondaryFor(context))))
                    : ListView(
                        children: tags.map((name) => Padding(
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
                              title: Text('#$name', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textFor(context))),
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
