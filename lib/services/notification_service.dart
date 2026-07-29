import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const String _channelId = 'easyfinance_reminders';
const String _channelName = 'Напоминания EasyFinance';
const int _dailyNotificationId = 1;
const String _lastOpenKey = 'easyfinance_last_open';

@pragma('vm:entry-point')
void notificationCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final plugin = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(const InitializationSettings(android: androidInit, iOS: DarwinInitializationSettings()));

    if (task == 'dailyCheck') {
      final prefs = await SharedPreferences.getInstance();
      await _runDailyCheck(plugin, prefs);
    }
    return true;
  });
}

Future<void> _runDailyCheck(FlutterLocalNotificationsPlugin plugin, SharedPreferences prefs) async {
  final lastOpenStr = prefs.getString(_lastOpenKey);
  DateTime? lastOpen;
  if (lastOpenStr != null) {
    lastOpen = DateTime.tryParse(lastOpenStr);
  }

  if (lastOpen != null) {
    final daysSince = DateTime.now().difference(lastOpen).inDays;
    if (daysSince < 5) return;
  }

  final notifDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Напоминания о платежах и целях',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: const DarwinNotificationDetails(),
  );

  final plannedBody = _buildPlannedPaymentsText(prefs);
  if (plannedBody != null) {
    await plugin.show(_dailyNotificationId, 'Платежи завтра', plannedBody, notifDetails);
    return;
  }

  final goalBody = _buildGoalsText(prefs);
  if (goalBody != null) {
    await plugin.show(_dailyNotificationId, 'Цель близка!', goalBody, notifDetails);
    return;
  }
}

String? _buildPlannedPaymentsText(SharedPreferences prefs) {
  final raw = prefs.getString('easyfinance_planned_payments');
  if (raw == null) return null;

  final events = jsonDecode(raw) as List<dynamic>;
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final tomorrowStr = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

  final tomorrowEvents = events.where((e) {
    if (e['enabled'] == false) return false;
    return e['date'] == tomorrowStr;
  }).toList();

  if (tomorrowEvents.isEmpty) return null;

  final parts = tomorrowEvents.map((e) {
    final title = e['title'] as String? ?? '';
    final amount = (e['amount'] as num?)?.toDouble() ?? 0;
    return '$title ${amount.toStringAsFixed(0)} ₽';
  }).toList();

  return parts.join(', ');
}

String? _buildGoalsText(SharedPreferences prefs) {
  final raw = prefs.getString('easyfinance_goals');
  if (raw == null) return null;

  final goals = jsonDecode(raw) as List<dynamic>;
  final close = goals.where((g) {
    if (g['isCompleted'] == true) return false;
    final done = ((g['currentAmount'] ?? g['amount_done']) as num?)?.toDouble() ?? 0;
    final total = ((g['targetAmount'] ?? g['amount']) as num?)?.toDouble() ?? 0;
    return total > 0 && (done / total) >= 0.8;
  }).toList();

  if (close.isEmpty) return null;

  final titles = close.map((g) => g['title'] as String? ?? '').where((t) => t.isNotEmpty).toList();
  if (titles.isEmpty) return null;

  if (titles.length == 1) {
    return 'Не забудьте отложить средства на «${titles.first}»';
  }
  final joined = titles.map((t) => '«$t»').join(', ');
  return 'Не забудьте отложить средства на $joined';
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  FlutterLocalNotificationsPlugin? _plugin;

  Future<void> init() async {
    _plugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin!.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
  }

  Future<void> initializeForBackground() async {
    _plugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin!.initialize(
      const InitializationSettings(android: androidSettings, iOS: DarwinInitializationSettings()),
    );
  }

  Future<void> trackAppOpen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastOpenKey, DateTime.now().toIso8601String());
  }

  Future<void> rescheduleAll() async {
    await init();
    await _plugin?.cancelAll();
    await trackAppOpen();
  }

  Future<void> registerDailyTask() async {
    final now = DateTime.now();
    var next10 = DateTime(now.year, now.month, now.day, 10, 0);
    if (now.isAfter(next10)) {
      next10 = next10.add(const Duration(days: 1));
    }
    await Workmanager().registerPeriodicTask(
      'dailyCheck',
      'dailyCheck',
      frequency: const Duration(hours: 24),
      initialDelay: next10.difference(now),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.notRequired),
    );
  }
}
