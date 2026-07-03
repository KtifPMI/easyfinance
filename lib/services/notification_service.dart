import 'dart:convert';
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

const String _reminderChannelId = 'easyfinance_reminders';
const String _reminderChannelName = 'Напоминания EasyFinance';
const String _reminderChannelDesc = 'Напоминания о финансовых целях и платежах';

const int _inactiveNotificationId = 1;
const int _goalNotificationId = 2;
const int _plannedBaseId = 100;

@pragma('vm:entry-point')
void notificationCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final service = NotificationService();
    await service.initializeForBackground();
    final prefs = await SharedPreferences.getInstance();
    if (task == 'checkGoals') {
      await service._checkGoals(prefs);
    }
    return true;
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  FlutterLocalNotificationsPlugin? _plugin;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
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
    _initialized = true;
  }

  Future<void> initializeForBackground() async {
    _plugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin!.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _reminderChannelId,
        _reminderChannelName,
        channelDescription: _reminderChannelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  Future<void> _cancelAll() async {
    await _plugin?.cancelAll();
  }

  Future<void> rescheduleAll() async {
    await init();
    await _cancelAll();
    await _scheduleInactiveReminder();
    await _schedulePlannedPaymentReminders();
  }

  Future<void> _scheduleInactiveReminder() async {
    final scheduledDate = tz.TZDateTime.now(tz.local).add(const Duration(days: 5));
    await _plugin?.zonedSchedule(
      _inactiveNotificationId,
      'Давно не заходили',
      'Пора проверить свои финансы!',
      scheduledDate,
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _schedulePlannedPaymentReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('easyfinance_planned_payments');
    if (raw == null) return;

    final events = jsonDecode(raw) as List<dynamic>;
    final today = tz.TZDateTime.now(tz.local);
    int notifId = _plannedBaseId;

    for (final e in events) {
      if (e['enabled'] == false) continue;
      final dateStr = e['date'] as String?;
      if (dateStr == null || dateStr.isEmpty) continue;
      final eventDate = DateTime.tryParse(dateStr);
      if (eventDate == null) continue;

      final remindAt = tz.TZDateTime(tz.local, eventDate.year, eventDate.month, eventDate.day - 1, 10, 0);
      if (remindAt.isAfter(today)) {
        await _plugin?.zonedSchedule(
          notifId++,
          'Плановый платёж завтра',
          '${e['title']} — ${(e['amount'] as num?)?.toDouble() ?? 0} руб.',
          remindAt,
          _details(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  Future<void> _checkGoals(SharedPreferences prefs) async {
    final raw = prefs.getString('easyfinance_goals');
    if (raw == null) return;

    final goals = jsonDecode(raw) as List<dynamic>;
    final close = goals.where((g) {
      final done = (g['amount_done'] as num?)?.toDouble() ?? 0;
      final total = (g['amount'] as num?)?.toDouble() ?? 0;
      return total > 0 && (done / total) >= 0.8 && (done / total) < 1.0;
    }).toList();

    if (close.isEmpty) return;

    final titles = [
      'Осталось совсем чуть-чуть!',
      'Цель уже близко!',
      'Почти у цели!',
      'Рывок до цели!',
    ];
    final bodies = [
      'Осталось немного — не останавливайтесь!',
      'Вы почти у цели!',
      'Ещё чуть-чуть!',
      'Последний шаг!',
    ];

    final rng = Random();
    await _plugin?.show(
      _goalNotificationId,
      titles[rng.nextInt(titles.length)],
      bodies[rng.nextInt(bodies.length)],
      _details(),
    );
  }

  Future<void> registerDailyTask() async {
    await Workmanager().registerPeriodicTask(
      'dailyFinanceCheck',
      'checkGoals',
      frequency: const Duration(hours: 24),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.notRequired),
    );
  }
}
