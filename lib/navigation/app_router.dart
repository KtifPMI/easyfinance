import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/oauth_webview_screen.dart';
import '../screens/debug/debug_screen.dart';
import '../screens/operations/add_operation_screen.dart';
import '../screens/operations/operation_detail_screen.dart';
import 'tab_router.dart';

class AppRouter {
  static const String login = '/login';
  static const String oauth = '/oauth';
  static const String main = '/main';
  static const String addOperation = '/add-operation';
  static const String operationDetail = '/operation-detail';
  static const String debug = '/debug';

  static Map<String, Widget Function(BuildContext)> get routes => {
    login: (_) => const LoginScreen(),
    oauth: (_) => const OAuthWebViewScreen(),
    main: (_) => const MainTabs(),
    addOperation: (_) => const AddOperationScreen(),
    operationDetail: (_) => const OperationDetailScreen(),
    debug: (_) => const DebugScreen(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == addOperation) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => AddOperationScreen(
          type: args?['type'] as String?,
          operationId: args?['operationId'] as String?,
        ),
        settings: settings,
      );
    }
    return null;
  }
}
