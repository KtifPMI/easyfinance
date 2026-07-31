import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../components/common/screen_scaffold.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final msg = _msgCtrl.text.trim();
    if (title.isEmpty || msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('support.fill_all'))));
      return;
    }
    setState(() => _sending = true);
    try {
      final api = context.read<FinanceStore>().apiClient;
      final result = await api.sendFeedback(title: title, message: msg);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('support.error')), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: context.tr('support.title'),
      showLogo: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInput(
            controller: _titleCtrl,
            label: context.tr('support.topic'),
            hint: context.tr('support.topic_hint'),
          ),
          const SizedBox(height: 16),
          AppInput(
            controller: _msgCtrl,
            label: context.tr('support.message'),
            hint: context.tr('support.message_hint'),
            maxLines: 6,
          ),
          const SizedBox(height: 24),
          AppButton(
            title: context.tr('support.send'),
            loading: _sending,
            onPressed: _sending ? null : _send,
          ),
        ],
      ),
    );
  }
}
