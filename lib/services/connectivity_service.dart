import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_constants.dart';

/// Détecte le retour de connexion pour déclencher la synchronisation automatique.
///
/// `connectivity_plus` indique seulement qu'une interface réseau est active (wifi,
/// données mobiles) : ça ne garantit pas que le serveur Lapinou est joignable
/// (wifi sans internet, portail captif, DNS/TLS cassé sur ce domaine précis...),
/// donc on vérifie en plus une requête HTTP réelle vers l'API avant de considérer
/// l'appareil comme réellement en ligne. Toute réponse HTTP (même une erreur
/// 4xx/5xx) prouve que le serveur est joignable ; seule une erreur de connexion
/// (DNS, TLS, timeout, connexion refusée) est considérée comme "hors-ligne".
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final _connectivity = Connectivity();
  final _onlineController = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _lastKnownOnline = false;

  Stream<bool> get onOnlineChanged => _onlineController.stream;
  bool get lastKnownOnline => _lastKnownOnline;

  void start() {
    _subscription ??= _connectivity.onConnectivityChanged.listen((_) async {
      final online = await isOnline();
      if (online != _lastKnownOnline) {
        _lastKnownOnline = online;
        _onlineController.add(online);
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.every((r) => r == ConnectivityResult.none)) {
        return false;
      }
      await http
          .head(Uri.parse(ApiConstants.baseUrl))
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      debugPrint('Connectivity check to ${ApiConstants.baseUrl} failed: $e');
      return false;
    }
  }
}
