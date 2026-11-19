import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Une échéance à rappeler par notification.
class ScheduledReminder {
  final String title;
  final String body;

  /// Jour de l'échéance (heure ignorée)
  final DateTime day;

  const ScheduledReminder({
    required this.title,
    required this.body,
    required this.day,
  });
}

/// Rappels d'élevage programmés sur le téléphone (sans serveur ni Firebase) :
/// une notification à [notifyHour] h pour chaque échéance du plan (voir
/// `breedingNotifications` : palpation, boîte à nid, mise bas, sevrage, soins). Les notifications sont reprogrammées à chaque changement des
/// données d'élevage, et survivent au redémarrage du téléphone.
///
/// Tant que [init] n'a pas été appelé (tests, web…), toutes les méthodes sont
/// sans effet.
class ReminderNotifications {
  ReminderNotifications._();
  static final instance = ReminderNotifications._();

  static const int notifyHour = 8;

  /// iOS limite à 64 notifications programmées par app
  static const int _maxScheduled = 50;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Timer? _debounce;
  String? _lastPlan;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'breeding_reminders',
      'Rappels d\'élevage',
      channelDescription:
          'Palpations, boîte à nid, mises bas, sevrages et soins à prévoir',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // La permission est demandée plus tard, une fois connecté
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications indisponibles: $e');
    }
  }

  /// Demande l'autorisation d'afficher des notifications (Android 13+, iOS).
  /// Le système ne pose la question qu'une fois.
  Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('Permission notifications: $e');
    }
  }

  /// Reprogramme les rappels (regroupe les changements rapprochés).
  void schedule(List<ScheduledReminder> reminders) {
    if (!_ready) return;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(seconds: 2),
      () => _apply(reminders),
    );
  }

  /// Retire tous les rappels (déconnexion).
  Future<void> clear() async {
    if (!_ready) return;
    _debounce?.cancel();
    _lastPlan = null;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Annulation des rappels: $e');
    }
  }

  /// Échéances futures uniquement, triées, à [notifyHour] h, plafonnées.
  @visibleForTesting
  static List<(DateTime, ScheduledReminder)> plan(
    List<ScheduledReminder> reminders,
    DateTime now,
  ) {
    final upcoming =
        reminders
            .map(
              (r) => (
                DateTime(r.day.year, r.day.month, r.day.day, notifyHour),
                r,
              ),
            )
            .where((e) => e.$1.isAfter(now))
            .toList()
          ..sort((a, b) => a.$1.compareTo(b.$1));
    return upcoming.take(_maxScheduled).toList();
  }

  Future<void> _apply(List<ScheduledReminder> reminders) async {
    final planned = plan(reminders, DateTime.now());
    // Rien n'a changé depuis la dernière programmation : on ne touche à rien
    final signature = planned
        .map((e) => '${e.$1.toIso8601String()}|${e.$2.title}|${e.$2.body}')
        .join('\n');
    if (signature == _lastPlan) return;

    try {
      await _plugin.cancelAll();
      for (var i = 0; i < planned.length; i++) {
        final (at, r) = planned[i];
        await _plugin.zonedSchedule(
          i,
          r.title,
          r.body,
          tz.TZDateTime.from(at, tz.UTC),
          _details,
          // Inexact : pas besoin de la permission « alarmes exactes »
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
      _lastPlan = signature;
    } catch (e) {
      debugPrint('Programmation des rappels: $e');
    }
  }
}
