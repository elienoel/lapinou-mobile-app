import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lapinou/providers/auth_provider.dart';
import 'package:lapinou/providers/chat_provider.dart';
import 'package:lapinou/theme/colors.dart';
import 'package:lapinou/providers/community_provider.dart';
import 'package:lapinou/screens/community_feed_screen.dart';
import 'package:lapinou/widgets/comments_sheet.dart';

Map<String, dynamic> _post(
  int id,
  int author,
  String name,
  String content,
  DateTime at, {
  int comments = 0,
}) => {
  'id': id,
  'author': author,
  'author_name': name,
  'author_farm': 'Ferme $name',
  'content': content,
  'comments_count': comments,
  'likes_count': 0,
  'created_at': at.toUtc().toIso8601String(),
};

Future<void> _pumpFeed(WidgetTester tester, List<Map<String, dynamic>> posts) async {
  SharedPreferences.setMockInitialValues({
    'auth_token': 'tok',
    'user_data': jsonEncode({
      'id': 7,
      'username': 'user_7',
      'phone_number': '+2250102030405',
      'first_name': 'Moi',
      'last_name': 'Même',
    }),
  });
  final client = MockClient((req) async {
    final data = req.url.path.endsWith('/posts/') ? posts : [];
    return http.Response(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  await http.runWithClient(() async {
    final auth = AuthProvider();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(create: (_) => CommunityProvider()),
          ChangeNotifierProvider(create: (_) => ChatProvider()),
        ],
        child: const MaterialApp(home: CommunityFeedScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }, () => client);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 9, 30);
  final yesterday = today.subtract(const Duration(days: 1));
  // Le serveur renvoie le plus récent en premier
  final posts = [
    _post(3, 7, 'Moi', 'Ma portée du jour', today, comments: 2),
    _post(2, 4, 'Awa', 'Quel granulé conseillez-vous ?', today.subtract(const Duration(hours: 1))),
    _post(1, 5, 'Koffi', 'Bonjour à tous', yesterday),
  ];

  testWidgets('posts are chat bubbles with the newest at the bottom', (tester) async {
    await _pumpFeed(tester, posts);

    // Les autres éleveurs : leur nom en tête de bulle ; ses propres messages : pas de nom
    expect(find.text('Awa'), findsOneWidget);
    expect(find.text('Koffi'), findsOneWidget);
    expect(find.text('Moi'), findsNothing);
    expect(find.text('Ma portée du jour'), findsOneWidget);

    // Ordre chronologique de haut en bas : Koffi (hier) → Awa → Moi (le plus récent, en bas)
    double y(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(y('Bonjour à tous'), lessThan(y('Quel granulé conseillez-vous ?')));
    expect(y('Quel granulé conseillez-vous ?'), lessThan(y('Ma portée du jour')));

    // Séparateurs de jour
    expect(find.text('Hier'), findsOneWidget);
    expect(find.text("Aujourd'hui"), findsOneWidget);
    expect(y('Hier'), lessThan(y('Bonjour à tous')));

    // Heure du message dans la bulle
    expect(find.byKey(const ValueKey('post-time-3')), findsOneWidget);
  });

  testWidgets('own messages use the primary colour at a very low opacity', (
    tester,
  ) async {
    await _pumpFeed(tester, posts);

    Finder bubbleOf(String text, Color color) => find.ancestor(
      of: find.text(text),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == color,
      ),
    );

    // Mon message : primaire translucide (jamais un fond noir plein)
    expect(bubbleOf('Ma portée du jour', AppColors.primaryTint), findsOneWidget);
    expect(bubbleOf('Ma portée du jour', AppColors.primary), findsNothing);
    expect(AppColors.primaryTint.a, lessThan(0.15));
    // Le message d'un autre éleveur reste sur fond blanc
    expect(bubbleOf('Quel granulé conseillez-vous ?', Colors.white), findsOneWidget);
  });

  testWidgets("each bubble keeps J'aime, Commenter and Partager", (tester) async {
    await _pumpFeed(tester, posts);

    expect(find.text("J'aime"), findsNWidgets(3));
    expect(find.text('Commenter'), findsNWidgets(3));
    expect(find.text('Partager'), findsNWidgets(3));
    expect(find.text('2 commentaires'), findsOneWidget);
  });

  testWidgets('Commenter opens the comments of that post', (tester) async {
    await _pumpFeed(tester, posts);

    await http.runWithClient(() async {
      await tester.tap(find.byKey(const ValueKey('post-comment-2')));
      await tester.pumpAndSettle();
    }, () => MockClient((_) async => http.Response(jsonEncode({'success': true, 'data': []}), 200)));
    expect(find.byType(CommentsSheet), findsOneWidget);
  });

  testWidgets('the composer stays at the bottom of the screen', (tester) async {
    await _pumpFeed(tester, posts);

    final composer = tester.getTopLeft(find.byKey(const ValueKey('feed-composer'))).dy;
    final lastMessage = tester.getTopLeft(find.text('Ma portée du jour')).dy;
    expect(composer, greaterThan(lastMessage));
    expect(find.text('Quoi de neuf ?'), findsOneWidget);
  });

  testWidgets('an empty feed shows the invitation to post', (tester) async {
    await _pumpFeed(tester, []);
    expect(find.text('Aucun message pour le moment'), findsOneWidget);
    expect(find.byKey(const ValueKey('feed-composer')), findsOneWidget);
  });
}
