import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:workmanager/workmanager.dart';
import 'navigation/app_router.dart';
import 'config.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/cloud_ocr_service.dart';
import 'store/finance_store.dart';
import 'store/locale_store.dart';
import 'store/planned_payment_store.dart';
import 'store/theme_store.dart';
import 'theme/theme.dart';
import 'utils/format.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

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
  final plannedPaymentStore = PlannedPaymentStore(apiClient: apiClient);
  await plannedPaymentStore.load();
  final themeStore = ThemeStore();
  await themeStore.load();

  try {
    final notif = NotificationService();
    await notif.init();
    await notif.rescheduleAll();
    await notif.registerDailyTask();
    await notif.trackAppOpen();
  } catch (e, stack) {
    debugPrint('Notification init error: $e\n$stack');
  }

  CloudOcrService.configure(
    apiKey: AppConfig.yandexVisionApiKey,
    folderId: AppConfig.yandexFolderId,
  );

  final prefs = await SharedPreferences.getInstance();
  showKopeks = prefs.getBool('easyfinance_show_kopeks') ?? true;
  showKopeksInOps = prefs.getBool('easyfinance_show_kopeks_ops') ?? true;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => _createFinanceStore(authService: authService, apiClient: apiClient, plannedPayments: plannedPaymentStore)),
        ChangeNotifierProvider.value(value: localeStore),
        ChangeNotifierProvider.value(value: plannedPaymentStore),
        ChangeNotifierProvider.value(value: themeStore),
      ],
      child: EasyLocalization(
        supportedLocales: const [
          Locale('ru'), Locale('en'), Locale('es'), Locale('it'),
          Locale('fr'), Locale('de'), Locale('pt'), Locale('tr'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('ru'),
        startLocale: localeStore.locale,
        child: const EasyFinanceApp(),
      ),
    ),
  );
}

FinanceStore _createFinanceStore({
  required AuthService authService,
  required ApiClient apiClient,
  required PlannedPaymentStore plannedPayments,
}) {
  final store = FinanceStore(authService: authService, apiClient: apiClient, plannedPayments: plannedPayments);
  // Аккаунт удалён на сайте — полный logout и переход на экран логина.
  store.onAccountDeleted = () {
    appNavigatorKey.currentState?.pushNamedAndRemoveUntil(AppRouter.login, (r) => false);
  };
  return store;
}

class EasyFinanceApp extends StatelessWidget {
  const EasyFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeStore = context.watch<ThemeStore>();
    return MaterialApp(
      title: 'EasyFinance',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeStore.themeMode,
      initialRoute: AppRouter.login,
      navigatorKey: appNavigatorKey,
      routes: AppRouter.routes,
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: Center(child: Text('Page not found')),
        ),
      ),
    );
  }
}
