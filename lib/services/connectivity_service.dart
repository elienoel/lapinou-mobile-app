import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Détecte le retour de connexion pour déclencher la synchronisation automatique.
///
/// `connectivity_plus` indique seulement qu'une interface réseau est active (wifi,
/// données mobiles) : ça ne garantit pas un accès réel à internet (wifi sans
/// internet, portail captif...), donc on vérifie en plus une résolution DNS légère
/// avant de considérer l'appareil comme réellement en ligne.
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
    final results = await _connectivity.checkConnectivity();
    if (results.every((r) => r == ConnectivityResult.none)) {
      return false;
    }
    try {
      final lookup = await InternetAddress.lookup(
        'example.com',
      ).timeout(const Duration(seconds: 3));
      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('Connectivity check failed: $e');
      return false;
    }
  }
}
