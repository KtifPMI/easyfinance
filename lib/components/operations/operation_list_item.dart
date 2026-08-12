import 'package:flutter/material.dart';
import '../../theme/theme.dart';

class OperationListItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<String> tags;
  final String formattedAmount;
  final String type;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isPending;

  const OperationListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.tags = const [],
    required this.formattedAmount,
    required this.type,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.onLongPress,
    this.isPending = false,
  });

  String get _amountPrefix {
    if (type == 'income') return '+';
    if (type == 'expense') return '-';
    return '';
  }

  Color _amountColor(BuildContext context) {
    if (type == 'income') return AppColors.income;
    if (type == 'expense') return AppColors.textFor(context);
    return AppColors.transfer;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context)))),
                  if (tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Wrap(
                        spacing: 4,
                        children: tags.map((t) => Text('#$t', style: TextStyle(fontSize: 12, color: AppColors.primary))).toList(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('$_amountPrefix$formattedAmount', maxLines: 1, softWrap: false, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _amountColor(context))),
            if (isPending) ...[
              const SizedBox(width: 4),
              Icon(Icons.sync, size: 14, color: AppColors.textSecondary),
            ],
          ],
        ),
      ),
    );
  }
}
