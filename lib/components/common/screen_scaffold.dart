import 'package:flutter/material.dart';
import 'skeleton_loader.dart';

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
            _buildSkeleton(context)
          else
            _buildBody(),
        ],
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const SkeletonLoader(height: 24, width: 200),
          const SizedBox(height: 24),
          const SkeletonLoader(height: 80),
          const SizedBox(height: 16),
          const SkeletonLoader(height: 80),
          const SizedBox(height: 16),
          const SkeletonLoader(height: 60, width: 150),
          const SizedBox(height: 16),
          Row(children: const [Expanded(child: SkeletonLoader(height: 80)), SizedBox(width: 12), Expanded(child: SkeletonLoader(height: 80))]),
          const SizedBox(height: 16),
          const SkeletonLoader(height: 12, width: 100),
          const SizedBox(height: 12),
          const SkeletonLoader(height: 60),
          const SizedBox(height: 8),
          const SkeletonLoader(height: 60),
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
