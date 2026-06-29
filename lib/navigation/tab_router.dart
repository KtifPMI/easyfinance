import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../screens/home/home_screen.dart';
import '../screens/operations/operations_list_screen.dart';
import '../screens/budget/plan_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/more/more_screen.dart';

class MainTabs extends StatefulWidget {
  const MainTabs({super.key});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    OperationsListScreen(),
    PlanScreen(),
    CalendarScreen(),
    ReportsScreen(),
    MoreScreen(),
  ];

  final _icons = [Icons.home_outlined, Icons.list_alt_outlined, Icons.track_changes_outlined, Icons.calendar_month_outlined, Icons.pie_chart_outline, Icons.menu_outlined];
  final _activeIcons = [Icons.home, Icons.list_alt, Icons.track_changes, Icons.calendar_month, Icons.pie_chart, Icons.menu];

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
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: List.generate(6, (i) => BottomNavigationBarItem(
          icon: Icon(_icons[i]),
          activeIcon: Icon(_activeIcons[i]),
          label: labels[i],
        )),
      ),
    );
  }
}
