import 'package:flutter/material.dart';
import '../../components/common/screen_scaffold.dart';
import '../../theme/theme.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _ctrl = TextEditingController();
  final _messages = <Map<String, String>>[];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _ctrl.clear();
      _messages.add({'role': 'assistant', 'text': 'Я ваш ИИ-ассистент. В демо-версии я отвечаю на вопросы об управлении финансами.'});
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'ИИ-ассистент',
      child: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.smart_toy_outlined, size: 64, color: AppColors.textSecondary),
                        const SizedBox(height: 16),
                        Text('Спросите о финансах', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUser ? AppColors.primary : AppColors.card,
                            borderRadius: BorderRadius.circular(12).copyWith(
                              bottomRight: isUser ? Radius.zero : const Radius.circular(12),
                              bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
                            ),
                          ),
                          child: Text(msg['text'] ?? '', style: TextStyle(color: isUser ? Colors.white : AppColors.text)),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  decoration: InputDecoration(
                    hintText: 'Введите вопрос...',
                    filled: true, fillColor: AppColors.card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.send, color: AppColors.primary),
                onPressed: _send,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
