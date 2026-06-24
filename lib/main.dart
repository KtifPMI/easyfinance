import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'navigation/app_router.dart';
import 'store/finance_store.dart';
import 'theme/theme.dart';

void main() {
  runApp(
    ChangeNotifierProvider(create: (_) => FinanceStore(), child: const EasyFinanceApp()),
  );
}

class EasyFinanceApp extends StatelessWidget {
  const EasyFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EasyFinance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRouter.login,
      routes: AppRouter.routes,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
