import 'package:flutter/material.dart';
import 'app_logo.dart';
import 'skeleton_loader.dart';

class ScreenScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool isLoading;
  final Future<void> Function()? onRefresh;
  final bool showLogo;

  const ScreenScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.floatingActionButton,
    this.isLoading = false,
    this.onRefresh,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasTitle = title.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: hasTitle
            ? Stack(
                alignment: Alignment.center,
                children: [
                  if (showLogo)
                    const Positioned(
                      left: 4,
                      child: AppLogo(height: 26),
                    ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : (showLogo
                ? Row(children: const [AppLogo(height: 28)])
                : null),
        actions: actions,
      ),
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
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(height: 16),
          SkeletonLoader(height: 24, width: 200),
          SizedBox(height: 24),
          SkeletonLoader(height: 80),
          SizedBox(height: 16),
          SkeletonLoader(height: 80),
          SizedBox(height: 16),
          SkeletonLoader(height: 60, width: 150),
          SizedBox(height: 16),
          Row(children: [Expanded(child: SkeletonLoader(height: 80)), SizedBox(width: 12), Expanded(child: SkeletonLoader(height: 80))]),
          SizedBox(height: 16),
          SkeletonLoader(height: 12, width: 100),
          SizedBox(height: 12),
          SkeletonLoader(height: 60),
          SizedBox(height: 8),
          SkeletonLoader(height: 60),
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
