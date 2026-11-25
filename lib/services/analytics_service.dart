import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

/// Service centralisé pour la surveillance de l'application :
/// - Rapports de crashs (Firebase Crashlytics)
/// - Métriques et télémétrie d'utilisation (Firebase Analytics)
/// - Diagnostics et capture d'erreurs manuelles
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  bool _initialized = false;
  FirebaseAnalytics? _analytics;

  FirebaseAnalytics? get analytics => _analytics;

  /// Initialise Firebase, Crashlytics et Analytics.
  /// Configure également les hooks de capture globale des exceptions.
  Future<void> init() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      _analytics = FirebaseAnalytics.instance;

      // En mode debug, on peut désactiver ou laisser activé la collecte Crashlytics
      // selon le besoin. En production (ou test réel), la collecte est activée.
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

      // 1. Capture des erreurs du framework Flutter (layout, widgets...)
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };

      // 2. Capture de toutes les erreurs non interceptées du moteur Dart / PlatformDispatcher
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      _initialized = true;
      debugPrint('Firebase & Crashlytics initialisés avec succès.');
    } catch (e, stack) {
      debugPrint('Avertissement: Échec initialisation Firebase: $e\n$stack');
    }
  }

  /// Associe l'utilisateur connecté aux rapports de crash et aux métriques.
  Future<void> setUser({required String userId, String? email, String? phone}) async {
    if (!_initialized) return;
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(userId);
      if (email != null) {
        await FirebaseCrashlytics.instance.setCustomKey('user_email', email);
      }
      if (phone != null) {
        await FirebaseCrashlytics.instance.setCustomKey('user_phone', phone);
      }
      await _analytics?.setUserId(id: userId);
    } catch (e) {
      debugPrint('Erreur setUser Crashlytics: $e');
    }
  }

  /// Réinitialise l'identifiant lors de la déconnexion.
  Future<void> clearUser() async {
    if (!_initialized) return;
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier('');
      await _analytics?.setUserId(id: null);
    } catch (e) {
      debugPrint('Erreur clearUser Crashlytics: $e');
    }
  }

  /// Enregistre une erreur manuelle / silencieuse (ex: requête réseau échouée, sync échec).
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    if (!_initialized) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        exception,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } catch (e) {
      debugPrint('Erreur recordError Crashlytics: $e');
    }
  }

  /// Ajoute une trace (breadcrumb) avant un crash potentiel.
  void log(String message) {
    if (!_initialized) return;
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (e) {
      debugPrint('Erreur log Crashlytics: $e');
    }
  }

  /// Trace un événement métier personnalisé dans Analytics.
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    if (!_initialized) return;
    try {
      await _analytics?.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint('Erreur logEvent Analytics: $e');
    }
  }
}
