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
import '../screens/planned_payments/planned_payments_screen.dart';
import '../screens/planned_payments/add_planned_payment_screen.dart';
import '../models/financial_event.dart';
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
  static const String plannedPayments = '/planned-payments';
  static const String addPlannedPayment = '/add-planned-payment';

  static Map<String, Widget Function(BuildContext)> get routes => {
    login: (_) => const LoginScreen(),
    oauth: (_) => const OAuthWebViewScreen(),
    register: (_) => const RegisterScreen(),
    pin: (_) => const PinScreen(),
    main: (_) => const MainTabs(),
    addOperation: (_) => const AddOperationScreen(),
    scanReceipt: (_) => const ScanReceiptScreen(),
    aiAssistant: (_) => const AiAssistantScreen(),
    operationDetail: (_) => const OperationDetailScreen(),
    debug: (_) => const DebugScreen(),
    plannedPayments: (_) => const PlannedPaymentsScreen(),
    addPlannedPayment: (_) => const AddPlannedPaymentScreen(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    Widget? page;
    if (settings.name == addOperation) {
      final args = settings.arguments as Map<String, dynamic>?;
      page = AddOperationScreen(
        type: args?['type'] as String?,
        operationId: args?['operationId'] as String?,
        presetDate: args?['presetDate'] as String?,
        templateId: args?['templateId'] as String?,
      );
    } else if (settings.name == addPlannedPayment) {
      final arg = settings.arguments;
      if (arg is FinancialEvent) {
        page = AddPlannedPaymentScreen(existing: arg);
      } else {
        final presetDate = arg is Map ? arg['date'] as String? : null;
        page = AddPlannedPaymentScreen(presetDate: presetDate);
      }
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
