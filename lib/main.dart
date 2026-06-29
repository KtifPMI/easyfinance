import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'navigation/app_router.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'store/finance_store.dart';
import 'store/locale_store.dart';
import 'store/planned_payment_store.dart';
import 'theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  const appId = '7e65ca8e482d55ad7ad31476d7b33dc64a7d0f60';
  const secretKey = 'e3df02801d7e7073a0d042f6a040aa043b9fc003';
  final apiClient = ApiClient(appId: appId, secretKey: secretKey);
  final authService = AuthService(apiClient);
  final localeStore = LocaleStore();
  await localeStore.load();
  final plannedPaymentStore = PlannedPaymentStore();
  await plannedPaymentStore.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FinanceStore(authService: authService, apiClient: apiClient)),
        ChangeNotifierProvider.value(value: localeStore),
        ChangeNotifierProvider.value(value: plannedPaymentStore),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('ru'), Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('ru'),
        startLocale: localeStore.locale,
        child: const EasyFinanceApp(),
      ),
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
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: AppTheme.light,
      initialRoute: AppRouter.login,
      routes: AppRouter.routes,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
