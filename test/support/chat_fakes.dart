import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lapinou/providers/auth_provider.dart';
import 'package:lapinou/providers/chat_provider.dart';

http.Response okResponse(dynamic data, {int status = 200}) => http.Response(
      jsonEncode({'success': true, 'data': data}),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> convJson({int id = 1, int unread = 0, Map<String, dynamic>? last}) => {
      'id': id,
      'other_user': {
        'id': 2,
        'name': 'Kofi Mensah',
        'farm_name': 'Ferme Mensah',
        'location': 'Bouaké',
        'avatar': null,
      },
      'last_message': last,
      'unread_count': unread,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

Map<String, dynamic> msgJson(int id, int sender, String text, {bool read = false}) => {
      'id': id,
      'conversation': 1,
      'sender': sender,
      'content': text,
      'image': null,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'is_read': read,
    };

/// Faux serveur : discussions, messages et envoi.
class FakeServer {
  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> conversations;
  int unread;
  bool failSends = false;
  int audioUploads = 0;
  final requests = <String>[];

  FakeServer({
    List<Map<String, dynamic>>? messages,
    this.conversations = const [],
    this.unread = 0,
  }) : messages = messages ?? [];

  MockClient client() => MockClient.streaming((request, bodyStream) async {
        final body = await bodyStream.bytesToString();
        final res = await _handle(request.method, request.url, body);
        return http.StreamedResponse(
          Stream.value(res.bodyBytes),
          res.statusCode,
          headers: res.headers,
        );
      });

  Future<http.Response> _handle(String method, Uri url, String body) async {
    requests.add('$method ${url.path}${url.hasQuery ? '?${url.query}' : ''}');
    final path = url.path;
    if (path.endsWith('/unread-count/')) return okResponse({'unread': unread});
    if (path.endsWith('/conversations/users/')) {
      return okResponse([
        {'id': 2, 'name': 'Kofi Mensah', 'farm_name': 'Ferme Mensah', 'location': 'Bouaké', 'avatar': null},
      ]);
    }
    if (path.endsWith('/messages/') && method == 'POST') {
      if (failSends) return http.Response('{}', 500);
      final sent = msgJson(100 + messages.length, 1, _textOf(body));
      if (body.contains('name="audio"')) {
        sent['audio'] = 'http://localhost:8000/media/chat/audio/note.m4a';
        sent['audio_duration_ms'] = _durationOf(body);
        audioUploads++;
      }
      messages.add(sent);
      return okResponse(sent, status: 201);
    }
    if (path.endsWith('/messages/')) {
      final after = int.tryParse(url.queryParameters['after_id'] ?? '');
      final list = after == null ? messages : messages.where((m) => m['id'] > after).toList();
      return okResponse({'messages': list, 'has_more': false, 'my_read_up_to': null});
    }
    if (path.endsWith('/conversations/') && method == 'POST') return okResponse(convJson(), status: 201);
    if (path.endsWith('/conversations/')) return okResponse(conversations);
    return http.Response('{}', 404);
  }

  int? _durationOf(String multipartBody) {
    final m = RegExp(r'name="audio_duration_ms"[^\r\n]*\r\n(?:[^\r\n]+\r\n)*\r\n(\d+)\r\n--')
        .firstMatch(multipartBody);
    return m == null ? null : int.parse(m.group(1)!);
  }

  String _textOf(String multipartBody) {
    // Les textes accentués ajoutent des en-têtes (content-type…) avant la ligne vide
    final m = RegExp(r'name="content"[^\r\n]*\r\n(?:[^\r\n]+\r\n)*\r\n(.*?)\r\n--')
        .firstMatch(multipartBody);
    return m?.group(1) ?? '';
  }
}

Future<AuthProvider> loggedInAuth(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'auth_token': 'tok',
    'user_data': jsonEncode({'id': 1, 'username': 'moi', 'first_name': 'Awa'}),
  });
  final auth = AuthProvider();
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
  return auth;
}

Widget chatApp(AuthProvider auth, ChatProvider chat, Widget home) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<ChatProvider>.value(value: chat),
      ],
      child: MaterialApp(home: home),
    );

