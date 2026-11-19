import 'dart:async';

import 'package:http/http.dart' as http;

/// Client HTTP global de l'application (installé dans `main()` via
/// `http.runWithClient`, donc utilisé par tous les `http.get/post/...` et les
/// `MultipartRequest.send()` des providers).
///
/// - Il remplace le jeton `Bearer` de chaque requête par le jeton courant :
///   un provider qui aurait gardé un ancien jeton envoie quand même le bon.
/// - Sur une réponse 401, il renouvelle la session une seule fois (même si
///   plusieurs requêtes échouent en même temps) puis rejoue la requête.
///   Les envois de fichiers (multipart) ne peuvent pas être rejoués : ils
///   repartent simplement avec le jeton à jour la fois suivante.
class AuthHttpClient extends http.BaseClient {
  AuthHttpClient(this._inner);

  final http.Client _inner;

  /// Jeton d'accès courant (tenu à jour par `AuthProvider`).
  static String? currentToken;

  /// Renouvelle la session ; renvoie le nouveau jeton d'accès, ou null si la
  /// session ne peut pas être renouvelée (fourni par `AuthProvider`).
  static Future<String?> Function()? refreshSession;

  static Future<String?>? _refreshing;

  /// Un seul renouvellement à la fois : les requêtes en échec attendent le même.
  static Future<String?> _refreshOnce() {
    final refresh = refreshSession;
    if (refresh == null) return Future.value(null);
    return _refreshing ??= refresh().whenComplete(() => _refreshing = null);
  }

  static bool _usesBearer(http.BaseRequest r) =>
      r.headers['Authorization']?.startsWith('Bearer ') ?? false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!_usesBearer(request)) return _inner.send(request);

    final token = currentToken;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    // Copie gardée avant l'envoi : une requête déjà envoyée ne peut pas repartir
    final retry = request is http.Request ? _copy(request) : null;
    final response = await _inner.send(request);
    if (response.statusCode != 401 || retry == null) return response;

    final newToken = await _refreshOnce();
    if (newToken == null) return response;

    await response.stream.drain<void>();
    retry.headers['Authorization'] = 'Bearer $newToken';
    return _inner.send(retry);
  }

  static http.Request _copy(http.Request r) {
    final copy =
        http.Request(r.method, r.url)
          ..headers.addAll(r.headers)
          ..followRedirects = r.followRedirects
          ..maxRedirects = r.maxRedirects
          ..persistentConnection = r.persistentConnection;
    if (r.bodyBytes.isNotEmpty) copy.bodyBytes = r.bodyBytes;
    return copy;
  }

  /// Sans effet : le client réel est partagé par toute l'app. Les appels
  /// `http.get(...)` (et google_fonts) créent un client puis le ferment après
  /// chaque requête ; le fermer pour de bon bloquerait toutes les suivantes.
  @override
  void close() {}
}
