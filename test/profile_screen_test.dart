import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lapinou/providers/auth_provider.dart';
import 'package:lapinou/providers/rabbit_provider.dart';
import 'package:lapinou/screens/profile_screen.dart';

Future<void> _pumpProfile(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'auth_token': 'tok',
    'user_data': jsonEncode({
      'id': 7,
      'username': 'user_225',
      'phone_number': '+2250102030405',
      'first_name': 'Awa',
      'last_name': 'Koné',
      'farm_name': 'Clapier du Lac',
      'location': 'Bouaké',
      'email': 'awa@lac.ci',
      'bio': 'Éleveuse de fauves',
      'created_at': '2026-03-05T10:00:00Z',
    }),
  });
  final auth = AuthProvider();
  await tester.runAsync(
    () => Future.delayed(const Duration(milliseconds: 200)),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider(
          create: (_) => RabbitProvider()..seedForTesting(),
        ),
      ],
      child: const MaterialApp(home: ProfileScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  test('AuthUser keeps bio and creation date through JSON', () {
    final user = AuthUser.fromJson({
      'id': 1,
      'username': 'u',
      'bio': 'Bonjour',
      'created_at': '2026-03-05T10:00:00Z',
    });
    final copy = AuthUser.fromJson(user.toJson());
    expect(copy.bio, 'Bonjour');
    expect(copy.createdAt, isNotNull);
    expect(copy.createdAt!.year, 2026);
  });

  testWidgets('personal information is read-only until Modifier is tapped', (
    tester,
  ) async {
    await _pumpProfile(tester);

    expect(find.text('Awa Koné'), findsOneWidget);
    expect(find.text('🏡 Clapier du Lac'), findsOneWidget);
    expect(find.text('+2250102030405'), findsOneWidget);
    expect(find.textContaining('Membre depuis le 5 mars 2026'), findsOneWidget);
    // statistiques de l'élevage
    expect(find.text('Lapins'), findsOneWidget);
    expect(find.text('Portées'), findsOneWidget);

    // les informations sont affichées, sans formulaire
    expect(find.text('Informations personnelles'), findsOneWidget);
    expect(find.text('Awa'), findsOneWidget);
    expect(find.text('Koné'), findsOneWidget);
    expect(find.text('Bouaké'), findsOneWidget);
    expect(find.text('awa@lac.ci'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Enregistrer'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('profile-edit')));
    await tester.pump();

    expect(find.widgetWithText(TextFormField, 'Awa'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'awa@lac.ci'), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-edit')), findsNothing);
  });

  testWidgets('empty fields show a placeholder in read mode', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'tok',
      'user_data': jsonEncode({
        'id': 8,
        'username': 'user_1',
        'phone_number': '+2250101010101',
      }),
    });
    final auth = AuthProvider();
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(create: (_) => RabbitProvider()),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Non renseigné'), findsNWidgets(6));
  });

  testWidgets('cancelling closes the form and discards the changes', (
    tester,
  ) async {
    await _pumpProfile(tester);

    await tester.tap(find.byKey(const ValueKey('profile-edit')));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextFormField, 'Awa'), 'Zoé');
    await tester.ensureVisible(find.byKey(const ValueKey('profile-cancel')));
    await tester.tap(find.byKey(const ValueKey('profile-cancel')));
    await tester.pump();

    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Awa'), findsOneWidget);
    expect(find.text('Zoé'), findsNothing);

    // rouvrir le formulaire repart des valeurs du compte
    await tester.ensureVisible(find.byKey(const ValueKey('profile-edit')));
    await tester.tap(find.byKey(const ValueKey('profile-edit')));
    await tester.pump();
    expect(find.widgetWithText(TextFormField, 'Awa'), findsOneWidget);
  });

  testWidgets('saving updates the displayed information and closes the form', (
    tester,
  ) async {
    await _pumpProfile(tester);
    String? sent;
    final client = MockClient((req) async {
      sent = req.body;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'id': 7,
            'username': 'user_225',
            'phone_number': '+2250102030405',
            'first_name': 'Zoé',
            'last_name': 'Koné',
            'farm_name': 'Clapier du Lac',
            'location': 'Bouaké',
            'email': 'awa@lac.ci',
            'bio': 'Éleveuse de fauves',
            'created_at': '2026-03-05T10:00:00Z',
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await http.runWithClient(() async {
      await tester.tap(find.byKey(const ValueKey('profile-edit')));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextFormField, 'Awa'), 'Zoé');
      await tester.ensureVisible(find.byKey(const ValueKey('profile-save')));
      await tester.tap(find.byKey(const ValueKey('profile-save')));
      await tester.pumpAndSettle();
    }, () => client);

    expect(jsonDecode(sent!)['first_name'], 'Zoé');
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Zoé'), findsOneWidget);
    expect(find.text('Profil enregistré'), findsOneWidget);
  });

  testWidgets('invalid email blocks saving', (tester) async {
    await _pumpProfile(tester);

    await tester.tap(find.byKey(const ValueKey('profile-edit')));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'awa@lac.ci'),
      'pas-un-email',
    );
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(find.text('Adresse email invalide'), findsOneWidget);
    // le formulaire reste ouvert pour corriger
    expect(find.byType(TextFormField), findsWidgets);
  });

  testWidgets('tapping the avatar offers photo choices', (tester) async {
    await _pumpProfile(tester);

    await tester.tap(find.byIcon(Icons.photo_camera));
    await tester.pumpAndSettle();

    expect(find.text('Choisir dans la galerie'), findsOneWidget);
    expect(find.text('Prendre une photo'), findsOneWidget);
    // pas de photo enregistrée : pas d'option de suppression
    expect(find.text('Supprimer la photo'), findsNothing);
  });

  testWidgets('deleting the account requires typing SUPPRIMER', (tester) async {
    await _pumpProfile(tester);

    await tester.ensureVisible(find.text('Supprimer mon compte'));
    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pumpAndSettle();

    ElevatedButton confirm() => tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Supprimer'),
    );
    expect(confirm().onPressed, isNull);

    await tester.enterText(find.byType(TextField).last, 'supprimer');
    await tester.pump();
    expect(confirm().onPressed, isNotNull);
  });
}
