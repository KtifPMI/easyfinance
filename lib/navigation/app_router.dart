import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/oauth_webview_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/debug/debug_screen.dart';
import '../screens/operations/add_operation_screen.dart';
import '../screens/operations/operation_detail_screen.dart';
import '../screens/planned_payments/planned_payments_screen.dart';
import '../screens/planned_payments/add_planned_payment_screen.dart';
import '../models/financial_event.dart';
import 'tab_router.dart';

class AppRouter {
  static const String login = '/login';
  static const String oauth = '/oauth';
  static const String register = '/register';
  static const String main = '/main';
  static const String addOperation = '/add-operation';
  static const String operationDetail = '/operation-detail';
  static const String debug = '/debug';
  static const String plannedPayments = '/planned-payments';
  static const String addPlannedPayment = '/add-planned-payment';

  static Map<String, Widget Function(BuildContext)> get routes => {
    login: (_) => const LoginScreen(),
    oauth: (_) => const OAuthWebViewScreen(),
    register: (_) => const RegisterScreen(),
    main: (_) => const MainTabs(),
    addOperation: (_) => const AddOperationScreen(),
    operationDetail: (_) => const OperationDetailScreen(),
    debug: (_) => const DebugScreen(),
    plannedPayments: (_) => const PlannedPaymentsScreen(),
    addPlannedPayment: (_) => const AddPlannedPaymentScreen(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == addOperation) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => AddOperationScreen(
          type: args?['type'] as String?,
          operationId: args?['operationId'] as String?,
          presetDate: args?['presetDate'] as String?,
        ),
        settings: settings,
      );
    }
    if (settings.name == addPlannedPayment) {
      final arg = settings.arguments;
      return MaterialPageRoute(
        builder: (_) => AddPlannedPaymentScreen(
          existing: arg is FinancialEvent ? arg : null,
        ),
        settings: settings,
      );
    }
    return null;
  }
}
