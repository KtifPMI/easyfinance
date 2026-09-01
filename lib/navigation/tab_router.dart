import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../services/update_service.dart';
import '../store/finance_store.dart';
import '../theme/theme.dart';
import '../screens/home/home_screen.dart';
import '../screens/operations/operations_list_screen.dart';
import '../screens/budget/plan_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/more/more_screen.dart';
import '../store/planned_payment_store.dart';

class MainTabs extends StatefulWidget {
  final int initialIndex;
  const MainTabs({super.key, this.initialIndex = 0});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  late int _index;

  final _screens = const [
    HomeScreen(),
    OperationsListScreen(showBackButton: false),
    PlanScreen(showBackButton: false),
    CalendarScreen(showBackButton: false),
    ReportsScreen(showBackButton: false),
    MoreScreen(showBackButton: false),
  ];

  final _icons = [Icons.home_outlined, Icons.list_alt_outlined, Icons.track_changes_outlined, Icons.calendar_month_outlined, Icons.pie_chart_outline, Icons.menu_outlined];
  final _activeIcons = [Icons.home, Icons.list_alt, Icons.track_changes, Icons.calendar_month, Icons.pie_chart, Icons.menu];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, _screens.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkAndShow(context);
      if (mounted) context.read<PlannedPaymentStore>().syncFromServer();
    });
  }

  @override
  void didUpdateWidget(covariant MainTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _index = widget.initialIndex.clamp(0, _screens.length - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = [
      context.tr('tab.home'),
      context.tr('tab.operations'),
      context.tr('tab.plan'),
      context.tr('tab.calendar'),
      context.tr('tab.reports'),
      context.tr('tab.more'),
    ];
    final authExpired = context.watch<FinanceStore>().authExpired;
    return Scaffold(
      body: Column(
        children: [
          if (authExpired) _buildSessionExpiredBanner(context),
          Expanded(child: IndexedStack(index: _index, children: _screens)),
        ],
      ),
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            selectedLabelStyle: const TextStyle(fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor?.withValues(alpha: 0.85) ?? Colors.white.withValues(alpha: 0.85),
            elevation: 0,
            items: List.generate(6, (i) => BottomNavigationBarItem(
              icon: Icon(_icons[i]),
              activeIcon: Icon(_activeIcons[i]),
              label: labels[i],
            )),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionExpiredBanner(BuildContext context) {
    return Material(
      color: AppColors.danger.withValues(alpha: 0.1),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 18, color: AppColors.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('auth.session_expired'),
                  style: TextStyle(fontSize: 14, color: AppColors.danger),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/oauth'),
                child: Text(
                  context.tr('auth.sign_in_again'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.danger),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
