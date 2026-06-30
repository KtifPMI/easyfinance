import 'package:flutter/material.dart';
import '../../theme/theme.dart';

class ScreenScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;

  const ScreenScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.floatingActionButton,
    this.isLoading = false,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      floatingActionButton: floatingActionButton,
      body: Stack(
        children: [
          if (error != null && !isLoading)
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: AppColors.expense,
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(error!, style: const TextStyle(color: Colors.white, fontSize: 13))),
                    if (onRetry != null)
                      TextButton(
                        onPressed: onRetry,
                        child: const Text('Повторить', style: TextStyle(color: Colors.white)),
                      ),
                  ],
                ),
              ),
            ),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else
            SingleChildScrollView(
              padding: EdgeInsets.only(top: error != null ? 48.0 : 16, left: 16, right: 16, bottom: 16),
              child: child,
            ),
        ],
      ),
    );
  }
}
