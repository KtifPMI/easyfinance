import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:workmanager/workmanager.dart';
import 'navigation/app_router.dart';
import 'config.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'store/finance_store.dart';
import 'store/locale_store.dart';
import 'store/planned_payment_store.dart';
import 'theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  try {
    tz_data.initializeTimeZones();
    await Workmanager().initialize(notificationCallbackDispatcher);
  } catch (e, stack) {
    debugPrint('Workmanager init error: $e\n$stack');
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Unhandled Flutter error: ${details.exception}\n${details.stack}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled platform error: $error\n$stack');
    return true;
  };

  final apiClient = ApiClient(appId: AppConfig.appId, secretKey: AppConfig.secretKey);
  final authService = AuthService(apiClient);
  final localeStore = LocaleStore();
  await localeStore.load();
  final plannedPaymentStore = PlannedPaymentStore();
  await plannedPaymentStore.load();

  try {
    final notif = NotificationService();
    await notif.init();
    await notif.rescheduleAll();
    await notif.registerDailyTask();
  } catch (e, stack) {
    debugPrint('Notification init error: $e\n$stack');
  }

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
