import 'package:flutter/material.dart';
import '../../services/hint_service.dart';
import '../../theme/theme.dart';

class ScreenHint extends StatefulWidget {
  final String hintId;
  final String text;
  final Widget? icon;

  const ScreenHint({super.key, required this.hintId, required this.text, this.icon});

  @override
  State<ScreenHint> createState() => _ScreenHintState();
}

class _ScreenHintState extends State<ScreenHint> {
  bool _visible = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final seen = await HintService.isHintSeen(widget.hintId);
    if (mounted) setState(() { _visible = !seen; _loaded = true; });
  }

  void _dismiss() {
    setState(() => _visible = false);
    HintService.markSeen(widget.hintId);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || !_loaded) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.icon ?? Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.text, style: const TextStyle(fontSize: 13))),
          GestureDetector(
            onTap: _dismiss,
            child: Icon(Icons.close, size: 18, color: AppColors.textSecondaryFor(context)),
          ),
        ],
      ),
    );
  }
}
