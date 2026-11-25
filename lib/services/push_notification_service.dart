import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'reminder_notifications.dart';

/// Gestionnaire d'arrière-plan obligatoire pour Firebase Messaging sous Android/iOS.
/// Doit être une fonction de niveau supérieur (top-level).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Notification push reçue en arrière-plan: ${message.messageId}');
}

/// Service gérant la réception et l'affichage des notifications Push Firebase (FCM).
///
/// Fonctionnalités :
/// - Demande de permission push (iOS et Android 13+)
/// - Récupération et rafraîchissement du Token FCM
/// - Réception des messages au premier plan (Foreground) avec affichage via local_notifications
/// - Réception en arrière-plan et lors du clic sur la notification
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;
  bool _initialized = false;

  String? get fcmToken => _fcmToken;

  /// Initialise Firebase Messaging et configure les écouteurs d'événements.
  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Options de présentation au premier plan pour iOS
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Demande de permission
      await requestPermission();

      // Récupération initiale du token FCM
      await _retrieveToken();

      // Écoute du renouvellement du token par Firebase
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('FCM Token rafraîchi: $newToken');
      });

      // 1. Message reçu quand l'application est ouverte au premier plan
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Push reçu en avant-plan: ${message.notification?.title}');
        final notif = message.notification;
        if (notif != null) {
          ReminderNotifications.instance.showInstantNotification(
            title: notif.title ?? 'Clap\'in',
            body: notif.body ?? '',
          );
        }
      });

      // 2. Clic sur notification quand l'app était en arrière-plan
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App ouverte depuis notification: ${message.data}');
      });

      // 3. Notification qui a ouvert l'app depuis un état fermé (terminated)
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App lancée par notification: ${initialMessage.data}');
      }

      _initialized = true;
      debugPrint('PushNotificationService initialisé avec succès.');
    } catch (e) {
      debugPrint('Erreur initialisation PushNotificationService: $e');
    }
  }

  /// Demande l'autorisation d'afficher des notifications push.
  Future<void> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('Statut permission push: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('Erreur demande permission push: $e');
    }
  }

  Future<void> _retrieveToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('FCM Token: $_fcmToken');
    } catch (e) {
      debugPrint('Impossible de récupérer le token FCM: $e');
    }
  }
}
