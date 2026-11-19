import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:clap_in/services/auth_http_client.dart';

void main() {
  late List<String> seenTokens;
  late int refreshCalls;

  /// Serveur factice : n'accepte que le jeton « fresh ».
  http.Client server() => MockClient((req) async {
    final auth = req.headers['Authorization'] ?? '';
    seenTokens.add(auth);
    if (auth == 'Bearer fresh') return http.Response('{"ok":true}', 200);
    return http.Response('{"detail":"expired"}', 401);
  });

  setUp(() {
    seenTokens = [];
    refreshCalls = 0;
    AuthHttpClient.currentToken = 'stale';
    AuthHttpClient.refreshSession = () async {
      refreshCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      AuthHttpClient.currentToken = 'fresh';
      return 'fresh';
    };
  });

  tearDown(() {
    AuthHttpClient.currentToken = null;
    AuthHttpClient.refreshSession = null;
  });

  test('a 401 renews the session and replays the request with its body', () async {
    String? replayedBody;
    final client = AuthHttpClient(
      MockClient((req) async {
        seenTokens.add(req.headers['Authorization']!);
        if (req.headers['Authorization'] == 'Bearer fresh') {
          replayedBody = req.body;
          return http.Response('ok', 201);
        }
        return http.Response('expired', 401);
      }),
    );

    final res = await client.post(
      Uri.parse('https://api.test/farm/rabbits/'),
      headers: {'Authorization': 'Bearer stale'},
      body: '{"name":"Noisette"}',
    );

    expect(res.statusCode, 201);
    expect(refreshCalls, 1);
    expect(seenTokens, ['Bearer stale', 'Bearer fresh']);
    expect(replayedBody, '{"name":"Noisette"}');
  });

  test('parallel 401s share a single renewal', () async {
    final client = AuthHttpClient(server());
    final results = await Future.wait([
      for (var i = 0; i < 3; i++)
        client.get(
          Uri.parse('https://api.test/x/$i'),
          headers: {'Authorization': 'Bearer stale'},
        ),
    ]);

    expect(results.map((r) => r.statusCode), everyElement(200));
    expect(refreshCalls, 1);
  });

  test('an outdated token held by a provider is replaced by the current one', () async {
    AuthHttpClient.currentToken = 'fresh';
    final client = AuthHttpClient(server());
    final res = await client.get(
      Uri.parse('https://api.test/x'),
      headers: {'Authorization': 'Bearer old-one'},
    );

    expect(res.statusCode, 200);
    expect(refreshCalls, 0);
  });

  test('when the session cannot be renewed the 401 is returned as is', () async {
    AuthHttpClient.refreshSession = () async {
      refreshCalls++;
      return null;
    };
    final client = AuthHttpClient(server());
    final res = await client.get(
      Uri.parse('https://api.test/x'),
      headers: {'Authorization': 'Bearer stale'},
    );

    expect(res.statusCode, 401);
    expect(res.body, contains('expired'));
    expect(refreshCalls, 1);
  });

  test('http.get closing its client does not break later requests', () async {
    // Le vrai client partagé : refuse toute requête une fois fermé
    var closed = false;
    final shared = _ClosableClient(
      MockClient((_) async => http.Response('ok', 200)),
      onClose: () => closed = true,
    );

    await http.runWithClient(() async {
      // `http.get` crée un client, s'en sert puis le ferme (comme google_fonts)
      expect((await http.get(Uri.parse('https://fonts.test/a.ttf'))).statusCode, 200);
      expect((await http.get(Uri.parse('https://api.test/x'))).statusCode, 200);
    }, () => AuthHttpClient(shared));

    expect(closed, isFalse);
  });

  test('requests without a token are left untouched', () async {
    final client = AuthHttpClient(server());
    final res = await client.get(Uri.parse('https://api.test/public'));

    expect(res.statusCode, 401);
    expect(refreshCalls, 0);
    expect(seenTokens, ['']);
  });
}

/// Client qui échoue après `close()`, comme le vrai client HTTP.
class _ClosableClient extends http.BaseClient {
  _ClosableClient(this._inner, {required this.onClose});
  final http.Client _inner;
  final void Function() onClose;
  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (_closed) throw http.ClientException('Client is already closed.');
    return _inner.send(request);
  }

  @override
  void close() {
    _closed = true;
    onClose();
  }
}
