import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lapinou/models/chat.dart';
import 'package:lapinou/providers/chat_provider.dart';
import 'package:lapinou/screens/chat_screen.dart';
import 'package:lapinou/screens/conversations_screen.dart';
import 'package:lapinou/utils/time_ago.dart';
import 'package:lapinou/widgets/chat_icon_button.dart';
import 'support/chat_fakes.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('models & helpers', () {
    test('conversation parses preview, unread and other user', () {
      final c = ChatConversation.fromJson(convJson(
        unread: 3,
        last: {
          'id': 9,
          'sender': 2,
          'content': '',
          'has_image': true,
          'created_at': '2026-09-25T10:00:00Z',
        },
      ));
      expect(c.other.name, 'Kofi Mensah');
      expect(c.unread, 3);
      expect(c.last!.text, '📷 Photo');
      expect(c.last!.senderId, 2);
    });

    test('chat time labels', () {
      final now = DateTime.now();
      expect(chatDayLabel(now), "Aujourd'hui");
      expect(chatDayLabel(now.subtract(const Duration(days: 1))), 'Hier');
      expect(chatListTime(now.subtract(const Duration(days: 1))), 'Hier');
      expect(chatListTime(now).contains(':'), isTrue);
    });
  });

  group('ChatProvider', () {
    test('tracks unread total, sends messages and bumps the conversation', () async {
      final server = FakeServer(
        conversations: [
          convJson(id: 1, unread: 2, last: {
            'id': 5, 'sender': 2, 'content': 'Salut', 'has_image': false,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          }),
          convJson(id: 2),
        ],
      );
      final chat = ChatProvider(client: server.client());
      chat.setToken('tok');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await chat.fetchConversations();
      expect(chat.conversations.length, 2);
      expect(chat.unreadTotal, 2);

      // Lire la discussion fait tomber la pastille immédiatement
      await chat.fetchMessages(1);
      expect(chat.unreadTotal, 0);
      expect(chat.conversations.first.unread, 0);

      final sent = await chat.sendMessage(2, text: 'Bonjour');
      expect(sent.content, 'Bonjour');
      expect(chat.conversations.first.id, 2, reason: 'la discussion remonte en tête');
      expect(chat.conversations.first.last!.text, 'Bonjour');

      chat.setToken(null); // déconnexion : tout est vidé et le suivi s'arrête
      expect(chat.conversations, isEmpty);
      expect(chat.unreadTotal, 0);
      chat.dispose();
    });

    test('send failure surfaces a readable error', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'success': false,
              'message': {'default': 'Erreur'},
              'errors': {'content': ['Écrivez un message ou joignez une photo.']},
            }),
            400,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));
      final chat = ChatProvider(client: client)..setToken('tok');
      expect(
        () => chat.sendMessage(1, text: ''),
        throwsA(isA<ChatSendException>().having(
            (e) => e.message, 'message', 'Écrivez un message ou joignez une photo.')),
      );
      chat.setToken(null);
    });
  });

  group('screens', () {
    testWidgets('conversation list shows names, previews and unread badge', (tester) async {
      final auth = await loggedInAuth(tester);
      final server = FakeServer(conversations: [
        convJson(id: 1, unread: 3, last: {
          'id': 5, 'sender': 2, 'content': 'Tu as des fauves ?', 'has_image': false,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }),
      ]);
      final chat = ChatProvider(client: server.client())..setToken('tok');

      await tester.pumpWidget(chatApp(auth, chat, const ConversationsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Kofi Mensah'), findsOneWidget);
      expect(find.text('Tu as des fauves ?'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.pumpWidget(const SizedBox()); // arrête le rafraîchissement périodique
      chat.setToken(null);
      chat.dispose();
    });

    testWidgets('empty list invites to start a discussion', (tester) async {
      final auth = await loggedInAuth(tester);
      final chat = ChatProvider(client: FakeServer().client())..setToken('tok');

      await tester.pumpWidget(chatApp(auth, chat, const ConversationsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Aucune discussion pour le moment'), findsOneWidget);
      expect(find.text('Nouvelle discussion'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      chat.dispose();
    });

    testWidgets('chat screen shows history, sends a message and receives new ones', (tester) async {
      final auth = await loggedInAuth(tester);
      final server = FakeServer(messages: [
        msgJson(10, 2, 'Bonjour Awa'),
        msgJson(11, 1, 'Salut Kofi', read: true),
      ]);
      final chat = ChatProvider(client: server.client())..setToken('tok');
      final conversation = ChatConversation.fromJson(convJson());

      await tester.pumpWidget(chatApp(auth, chat, ChatScreen(conversation: conversation)));
      await tester.pumpAndSettle();

      expect(find.text('Bonjour Awa'), findsOneWidget);
      expect(find.text('Salut Kofi'), findsOneWidget);
      expect(find.byIcon(Icons.done_all), findsOneWidget); // mon message lu

      // envoi
      await tester.enterText(find.byType(TextField), 'Tu as un mâle disponible ?');
      await tester.pump(); // le micro devient une flèche d'envoi
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Tu as un mâle disponible ?'), findsOneWidget);
      expect(find.byType(TextField).evaluate().isNotEmpty, isTrue);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);

      // un nouveau message de Kofi arrive : récupéré par l'actualisation automatique
      server.messages.add(msgJson(200, 2, 'Oui, à Bouaké'));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Oui, à Bouaké'), findsOneWidget);
      expect(server.requests.any((r) => r.contains('after_id=')), isTrue);

      await tester.pumpWidget(const SizedBox()); // arrête le rafraîchissement
      chat.setToken(null);
      chat.dispose();
    });

    testWidgets('empty conversation greets, failed send offers a retry', (tester) async {
      final auth = await loggedInAuth(tester);
      final server = FakeServer()..failSends = true;
      final chat = ChatProvider(client: server.client())..setToken('tok');
      final conversation = ChatConversation.fromJson(convJson());

      await tester.pumpWidget(chatApp(auth, chat, ChatScreen(conversation: conversation)));
      await tester.pumpAndSettle();
      expect(find.text('Dites bonjour à Kofi Mensah'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Bonjour');
      await tester.pump(); // le micro devient une flèche d'envoi
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(find.textContaining('touchez pour réessayer'), findsOneWidget);

      server.failSends = false;
      await tester.tap(find.text('Bonjour'));
      await tester.pumpAndSettle();
      expect(find.textContaining('touchez pour réessayer'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      chat.setToken(null);
      chat.dispose();
    });

    testWidgets('chat icon shows the unread badge', (tester) async {
      final auth = await loggedInAuth(tester);
      final chat = ChatProvider(client: FakeServer(unread: 4).client())..setToken('tok');
      await tester.pumpWidget(chatApp(auth, chat, const Scaffold(body: ChatIconButton())));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(find.text('4'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      chat.setToken(null);
      chat.dispose();
    });
  });
}
