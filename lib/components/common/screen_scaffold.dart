import 'package:flutter/material.dart';

class ScreenScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool isLoading;
  final Future<void> Function()? onRefresh;

  const ScreenScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.floatingActionButton,
    this.isLoading = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      floatingActionButton: floatingActionButton,
      body: Stack(
        children: [
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildBody(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final scrollable = SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 16),
      child: child,
    );

    if (onRefresh != null) {
      return RefreshIndicator(
        onRefresh: onRefresh!,
        child: scrollable,
      );
    }

    return scrollable;
  }
}
