import 'package:flutter/material.dart';
import 'app_logo.dart';
import 'skeleton_loader.dart';

class ScreenScaffold extends StatelessWidget {
  /// Width that fits the logo at its natural size (AppLogo height 28 -> ~73px).
  static const double _logoSlotWidth = 80;

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool isLoading;
  final Future<void> Function()? onRefresh;
  final bool showLogo;
  final bool forceLogo;
  final Widget? titleWidget;

  const ScreenScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.floatingActionButton,
    this.isLoading = false,
    this.onRefresh,
    this.showLogo = true,
    this.forceLogo = false,
    this.titleWidget,
  });

  @override
  Widget build(BuildContext context) {
    final hasTitle = title.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 0,
        title: titleWidget ?? (hasTitle ? _buildTitle(context) : null),
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

  /// Header with a perfectly screen-centered title.
  ///
  /// The leading and trailing slots have equal fixed widths so the title text
  /// stays centered regardless of a back button, the logo, or actions.
  Widget _buildTitle(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    Widget left;
    Widget right;

    if (forceLogo && canPop) {
      left = const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BackButton(),
          AppLogo(height: 28),
        ],
      );
      right = const Visibility(
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BackButton(),
            AppLogo(height: 28),
          ],
        ),
      );
    } else {
      final leading = canPop
          ? const BackButton()
          : (showLogo ? const AppLogo(height: 28) : null);
      final trailing = (actions == null || actions!.isEmpty)
          ? null
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions!,
            );
      final double slot = canPop
          ? kToolbarHeight
          : (showLogo ? _logoSlotWidth : kToolbarHeight);
      left = SizedBox(
        width: slot,
        child: Center(child: leading),
      );
      right = SizedBox(
        width: slot,
        child: Center(child: trailing),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          left,
          Expanded(
            child: Center(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          right,
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
