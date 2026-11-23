import 'dart:io';

import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Запрос нативного окна «Оцените приложение» (Play In-App Review / StoreKit).
///
/// Self-throttling нужен не для точного учёта оценок (Play его не сообщает),
/// а чтобы не дёргать API чаще, чем позволяет квота Google Play.
class ReviewService {
  ReviewService._();

  static const _keyLastAt = 'review_last_request_at_ms';
  static const _keyRequests = 'review_requests_count';
  static const _keySuccesses = 'review_success_ops_count';

  /// Не спрашиваем, пока пользователь не добавит хотя бы столько операций.
  static const _minSuccessfulOps = 5;

  /// Минимальный интервал между собственными запросами.
  static const _minInterval = Duration(days: 30);

  /// Всего попыток за время жизни приложения (Play и так ограничивает показ).
  static const _maxRequests = 4;

  static final InAppReview _review = InAppReview.instance;

  /// Вызывать только после успешного добавления операции.
  ///
  /// Все ошибки (нет Play Store, flavor direct без маркета, квота, сеть)
  /// намеренно глотаются — пользователь не должен видеть последствия.
  static Future<void> maybeRequestAfterOperation() async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) return;
      if (!await _review.isAvailable()) return;

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;

      final successes = (prefs.getInt(_keySuccesses) ?? 0) + 1;
      await prefs.setInt(_keySuccesses, successes);
      if (successes < _minSuccessfulOps) return;

      final requests = prefs.getInt(_keyRequests) ?? 0;
      if (requests >= _maxRequests) return;

      final lastAt = prefs.getInt(_keyLastAt) ?? 0;
      if (now - lastAt < _minInterval.inMilliseconds) return;

      await _review.requestReview();

      // Отмечаем попытку только если вызов прошёл без ошибки.
      await prefs.setInt(_keyLastAt, DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt(_keyRequests, requests + 1);
    } catch (_) {
      // Напрямую не сообщаем: окно может не появиться по квоте Play — это норма.
    }
  }
}
