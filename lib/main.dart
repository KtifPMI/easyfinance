import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'navigation/app_router.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'store/finance_store.dart';
import 'theme/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const appId = '7e65ca8e482d55ad7ad31476d7b33dc64a7d0f60';
  const secretKey = 'e3df02801d7e7073a0d042f6a040aa043b9fc003';
  final apiClient = ApiClient(appId: appId, secretKey: secretKey);
  final authService = AuthService(apiClient);

  runApp(
    ChangeNotifierProvider(
      create: (_) => FinanceStore(authService: authService, apiClient: apiClient),
      child: const EasyFinanceApp(),
    ),
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
