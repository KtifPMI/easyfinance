import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/operations/add_operation_screen.dart';
import 'tab_router.dart';

class AppRouter {
  static const String login = '/login';
  static const String main = '/main';
  static const String addOperation = '/add-operation';

  static Map<String, Widget Function(BuildContext)> get routes => {
    login: (_) => const LoginScreen(),
    main: (_) => const MainTabs(),
    addOperation: (_) => const AddOperationScreen(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == addOperation) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => AddOperationScreen(type: args?['type'] as String?),
        settings: settings,
      );
    }
    return null;
  }
}
