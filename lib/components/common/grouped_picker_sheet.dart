import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/theme.dart';

class GroupedPickerSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) labelBuilder;
  final String Function(T)? groupBuilder;
  final String? Function(T)? subtitleBuilder;
  final IconData Function(T)? iconBuilder;
  final Color Function(T)? colorBuilder;
  final T? selectedId;
  final ValueChanged<T> onSelected;

  const GroupedPickerSheet({
    super.key,
    required this.title,
    required this.items,
    required this.labelBuilder,
    this.groupBuilder,
    this.subtitleBuilder,
    this.iconBuilder,
    this.colorBuilder,
    this.selectedId,
    required this.onSelected,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<T> items,
    required String Function(T) labelBuilder,
    String Function(T)? groupBuilder,
    String? Function(T)? subtitleBuilder,
    IconData Function(T)? iconBuilder,
    Color Function(T)? colorBuilder,
    T? selectedId,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => GroupedPickerSheet<T>(
          title: title,
          items: items,
          labelBuilder: labelBuilder,
          groupBuilder: groupBuilder,
          subtitleBuilder: subtitleBuilder,
          iconBuilder: iconBuilder,
          colorBuilder: colorBuilder,
          selectedId: selectedId,
          onSelected: (item) { Navigator.pop(ctx, item); },
        ),
      ),
    );
  }

  @override
  State<GroupedPickerSheet<T>> createState() => _GroupedPickerSheetState<T>();
}

class _GroupedPickerSheetState<T> extends State<GroupedPickerSheet<T>> {
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items.where((item) {
      if (_search.isEmpty) return true;
      return widget.labelBuilder(item).toLowerCase().contains(_search.toLowerCase());
    }).toList();

    final groups = <String, List<T>>{};
    for (final item in filtered) {
      final group = widget.groupBuilder?.call(item) ?? '';
      groups.putIfAbsent(group, () => []).add(item);
    }

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: Text(widget.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textFor(context)))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: context.tr('common.search'),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _search.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); }) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: groups.entries.length,
            itemBuilder: (ctx, gi) {
              final entry = groups.entries.elementAt(gi);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.key.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(entry.key.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondaryFor(context))),
                    const SizedBox(height: 4),
                  ],
                  ...entry.value.map((item) {
                    final isSelected = widget.selectedId != null && item == widget.selectedId;
                    final icon = widget.iconBuilder?.call(item);
                    final color = widget.colorBuilder?.call(item);
                    final subtitle = widget.subtitleBuilder?.call(item);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: icon != null ? Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: (color ?? AppColors.primary).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 18, color: color ?? AppColors.primary),
                      ) : null,
                      title: Text(widget.labelBuilder(item), style: TextStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: AppColors.textFor(context))),
                      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))) : null,
                      trailing: isSelected ? Icon(Icons.check_circle, color: AppColors.primary, size: 20) : null,
                      onTap: () => widget.onSelected(item),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
