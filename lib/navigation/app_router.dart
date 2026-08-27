import 'package:flutter/material.dart';
import '../screens/ai_assistant/ai_assistant_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/oauth_webview_screen.dart';
import '../screens/auth/pin_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/debug/debug_screen.dart';
import '../screens/operations/add_operation_screen.dart';
import '../screens/operations/operation_detail_screen.dart';
import '../screens/operations/scan_receipt_screen.dart';
import '../screens/accounts/accounts_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/recommendations/recommendations_screen.dart';
import '../screens/planned_payments/add_planned_payment_screen.dart';
import '../../models/financial_event.dart';
import 'tab_router.dart';

class AppRouter {
  static const String login = '/login';
  static const String oauth = '/oauth';
  static const String register = '/register';
  static const String pin = '/pin';
  static const String main = '/main';
  static const String addOperation = '/add-operation';
  static const String operationDetail = '/operation-detail';
  static const String scanReceipt = '/scan-receipt';
  static const String aiAssistant = '/ai-assistant';
  static const String debug = '/debug';
  static const String accounts = '/accounts';
  static const String operations = '/operations';
  static const String reports = '/reports';
  static const String plan = '/plan';
  static const String calendar = '/calendar';
  static const String settings = '/settings';
  static const String recommendations = '/recommendations';
  static const String addPlannedPayment = '/add-planned-payment';

  static const Map<String, int> tabIndexes = {
    main: 0,
    operations: 1,
    plan: 2,
    calendar: 3,
    reports: 4,
  };

  static Map<String, Widget Function(BuildContext)> get routes => {
    login: (_) => const LoginScreen(),
    oauth: (_) => const OAuthWebViewScreen(),
    register: (_) => const RegisterScreen(),
    pin: (_) => const PinScreen(),
    scanReceipt: (_) => const ScanReceiptScreen(),
    aiAssistant: (_) => const AiAssistantScreen(),
    operationDetail: (_) => const OperationDetailScreen(),
    debug: (_) => const DebugScreen(),
    accounts: (_) => const AccountsScreen(),
    settings: (_) => const SettingsScreen(),
    recommendations: (_) => const RecommendationsScreen(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    Widget? page;
    final name = settings.name;
    if (name == addOperation) {
      final args = settings.arguments as Map<String, dynamic>?;
      page = AddOperationScreen(
        type: args?['type'] as String?,
        operationId: args?['operationId'] as String?,
        presetDate: args?['presetDate'] as String?,
        templateId: args?['templateId'] as String?,
        copyFrom: args?['copyFrom'] as String?,
      );
    } else if (name != null && tabIndexes.containsKey(name)) {
      int tab = tabIndexes[name]!;
      final args = settings.arguments;
      if (args is Map && args['tab'] is int) {
        tab = args['tab'] as int;
      }
      page = MainTabs(initialIndex: tab);
    } else if (name == addPlannedPayment) {
      final args = settings.arguments;
      final existing = args is FinancialEvent ? args : null;
      final presetDate = args is Map ? (args['date'] as String?) : null;
      page = AddPlannedPaymentScreen(existing: existing, presetDate: presetDate);
    }
    if (page != null) {
      return PageRouteBuilder(
        settings: settings,
        pageBuilder: (_, __, ___) => page!,
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: FadeTransition(opacity: anim, child: child),
        ),
      );
    }
    return null;
  }
}
