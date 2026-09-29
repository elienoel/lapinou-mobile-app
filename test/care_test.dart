import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lapinou/models/care.dart';
import 'package:lapinou/providers/auth_provider.dart';
import 'package:lapinou/providers/rabbit_provider.dart';
import 'package:lapinou/screens/care_screen.dart';

String _iso(DateTime d) => isoDate(d);

Map<String, dynamic> _treatment(int id, String name, {int? days = 180}) => {
  'id': id,
  'name': name,
  'category': 'vaccine',
  'renewal_days': days,
  'records_count': 0,
};

Map<String, dynamic> _upcoming({
  required int record,
  required String name,
  required int days,
  required String status,
  List<String> rabbits = const ['p-f-2'],
}) {
  final due = DateTime.now().add(Duration(days: days));
  return {
    'record': record,
    'treatment': 5,
    'treatment_name': name,
    'treatment_category': 'vaccine',
    'purpose': 'Prévention VHD',
    'last_date': _iso(DateTime.now().subtract(const Duration(days: 180))),
    'due_date': _iso(due),
    'days_until_due': days,
    'status': status,
    'rabbits': [
      for (final id in rabbits)
        {'id': id, 'name': 'Lapin $id', 'tag_number': 'T-$id', 'gender': 'F'},
    ],
  };
}

class _CareApi {
  List<Map<String, dynamic>> treatments = [];
  List<Map<String, dynamic>> records = [];
  List<Map<String, dynamic>> upcoming = [];
  int? deleteStatus;
  String deleteBody = '{}';
  final requests = <String>[];

  MockClient client() => MockClient((req) async {
    requests.add('${req.method} ${req.url.path} ${req.body}');
    const headers = {'content-type': 'application/json; charset=utf-8'};
    if (req.method == 'GET') {
      final data =
          req.url.path.endsWith('care-treatments/')
              ? treatments
              : req.url.path.endsWith('upcoming/')
              ? upcoming
              : req.url.path.endsWith('care-records/')
              ? records
              : [];
      return http.Response(jsonEncode({'success': true, 'data': data}), 200, headers: headers);
    }
    if (req.method == 'DELETE' && deleteStatus != null) {
      return http.Response(deleteBody, deleteStatus!, headers: headers);
    }
    return http.Response(jsonEncode({'success': true, 'data': {}}), req.method == 'POST' ? 201 : 200, headers: headers);
  });

  String? last(String method) =>
      requests.lastWhere((r) => r.startsWith(method), orElse: () => '');
  Map<String, dynamic> bodyOf(String request) =>
      jsonDecode(request.substring(request.indexOf('{'))) as Map<String, dynamic>;
  List<String> writes() => requests.where((r) => !r.startsWith('GET')).toList();
}

Future<RabbitProvider> _pump(WidgetTester tester, {int initialTab = 0}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(420, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final provider = RabbitProvider()..seedForTesting();
  provider.setTokenForTesting('tok');
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<RabbitProvider>.value(value: provider),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(home: CareScreen(initialTab: initialTab)),
    ),
  );
  await tester.pumpAndSettle();
  return provider;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('Care models', () {
    test('renewal durations are readable', () {
      expect(renewalLabel(null), 'Soin ponctuel');
      expect(renewalLabel(7), 'Toutes les semaines');
      expect(renewalLabel(15), 'Tous les 15 jours');
      expect(renewalLabel(30), 'Tous les 1 mois');
      expect(renewalLabel(90), 'Tous les 3 mois');
      expect(renewalLabel(365), 'Tous les ans');
      expect(renewalLabel(730), 'Tous les 2 ans');
    });

    test('an upcoming care parses its urgency and countdown label', () {
      UpcomingCare parse(int days, String status) =>
          UpcomingCare.fromJson(_upcoming(record: 1, name: 'V', days: days, status: status));
      expect(parse(-3, 'overdue').status, DueStatus.overdue);
      expect(parse(-3, 'overdue').dueLabel, 'En retard de 3 j');
      expect(parse(0, 'soon').dueLabel, "Aujourd'hui");
      expect(parse(1, 'soon').dueLabel, 'Demain');
      expect(parse(20, 'upcoming').dueLabel, 'Dans 20 j');
      expect(parse(20, 'upcoming').rabbits.single.name, 'Lapin p-f-2');
    });
  });

  group('Care screen', () {
    testWidgets('reminders are flagged by urgency', (tester) async {
      final api =
          _CareApi()
            ..treatments = [_treatment(5, 'Vaccin VHD2')]
            ..upcoming = [
              _upcoming(record: 1, name: 'Vaccin VHD2', days: -10, status: 'overdue'),
              _upcoming(record: 2, name: 'Vitamine ADE', days: 4, status: 'soon'),
              _upcoming(record: 3, name: 'Vermifuge', days: 60, status: 'upcoming'),
            ];
      await http.runWithClient(() async {
        await _pump(tester);
        expect(find.text('À venir (3)'), findsOneWidget);
        expect(find.text('1 en retard'), findsOneWidget);
        expect(find.text('1 cette semaine'), findsOneWidget);
        expect(find.text('En retard de 10 j'), findsOneWidget);
        expect(find.text('Dans 4 j'), findsOneWidget);
        expect(find.text('Dans 60 j'), findsOneWidget);
        expect(find.text('Vaccin VHD2'), findsOneWidget);
      }, api.client);
    });

    testWidgets('renewing from a reminder prefills the form and saves', (tester) async {
      final api =
          _CareApi()
            ..treatments = [_treatment(5, 'Vaccin VHD2', days: 180)]
            ..upcoming = [_upcoming(record: 1, name: 'Vaccin VHD2', days: -2, status: 'overdue')];
      await http.runWithClient(() async {
        await _pump(tester);
        await tester.tap(find.byKey(const ValueKey('upcoming-done-1')));
        await tester.pumpAndSettle();

        // Type de soin, motif et lapins repris du rappel
        expect(find.text('Enregistrer un soin'), findsWidgets);
        expect(find.textContaining('prochain soin le'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byKey(const ValueKey('record-purpose'))).controller!.text,
          'Prévention VHD',
        );
        expect(
          tester.widget<CheckboxListTile>(find.byKey(const ValueKey('record-rabbit-p-f-2'))).value,
          isTrue,
        );

        await tester.tap(find.byKey(const ValueKey('record-submit')));
        await tester.pumpAndSettle();
      }, api.client);

      final post = api.last('POST')!;
      expect(post, contains('/farm/care-records/'));
      final body = api.bodyOf(post);
      expect(body['treatment'], 5);
      expect(body['rabbits'], ['p-f-2']);
      expect(body['purpose'], 'Prévention VHD');
      expect(body['date'], _iso(DateTime.now()));
      expect(find.text('Soin enregistré'), findsOneWidget);
    });

    testWidgets('a care needs a type and at least one rabbit', (tester) async {
      final api = _CareApi()..treatments = [_treatment(5, 'Vaccin VHD2')];
      await http.runWithClient(() async {
        await _pump(tester);
        await tester.tap(find.byKey(const ValueKey('care-fab-record')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('record-submit')));
        await tester.pumpAndSettle();
        expect(find.text('Choisissez le type de soin effectué.'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('record-treatment')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Vaccin VHD2').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('record-submit')));
        await tester.pumpAndSettle();
        expect(find.text('Sélectionnez au moins un lapin soigné.'), findsOneWidget);
        expect(api.writes(), isEmpty);

        // « Tous » coche tous les lapins, puis l'enregistrement part
        await tester.tap(find.byKey(const ValueKey('record-select-all')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('record-submit')));
        await tester.pumpAndSettle();
      }, api.client);

      final body = api.bodyOf(api.last('POST')!);
      expect(body['treatment'], 5);
      expect((body['rabbits'] as List), isNotEmpty);
    });

    testWidgets('a treatment is created with its renewal duration', (tester) async {
      final api = _CareApi();
      await http.runWithClient(() async {
        await _pump(tester, initialTab: 2);
        expect(find.text('Aucun type de soin'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('care-fab-treatment')));
        await tester.pumpAndSettle();

        // Nom obligatoire
        await tester.tap(find.byKey(const ValueKey('treatment-submit')));
        await tester.pumpAndSettle();
        expect(find.text('Donnez un nom à ce soin.'), findsOneWidget);

        await tester.enterText(find.byKey(const ValueKey('treatment-name')), 'Vitamine ADE');
        await tester.tap(find.byKey(const ValueKey('treatment-category-vitamin')));
        await tester.tap(find.byKey(const ValueKey('treatment-preset-90')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byKey(const ValueKey('treatment-days'))).controller!.text,
          '90',
        );
        await tester.tap(find.byKey(const ValueKey('treatment-submit')));
        await tester.pumpAndSettle();
      }, api.client);

      final post = api.last('POST')!;
      expect(post, contains('/farm/care-treatments/'));
      expect(api.bodyOf(post), containsPair('name', 'Vitamine ADE'));
      expect(api.bodyOf(post), containsPair('category', 'vitamin'));
      expect(api.bodyOf(post), containsPair('renewal_days', 90));
    });

    testWidgets('a one-off treatment is sent without renewal', (tester) async {
      final api = _CareApi();
      await http.runWithClient(() async {
        await _pump(tester, initialTab: 2);
        await tester.tap(find.byKey(const ValueKey('care-fab-treatment')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('treatment-name')), 'Bilan de santé');
        await tester.tap(find.byKey(const ValueKey('treatment-submit')));
        await tester.pumpAndSettle();
      }, api.client);
      expect(api.bodyOf(api.last('POST')!)['renewal_days'], isNull);
    });

    testWidgets('a treatment already used cannot be deleted', (tester) async {
      final api =
          _CareApi()
            ..treatments = [_treatment(5, 'Vaccin VHD2')]
            ..deleteStatus = 400
            ..deleteBody = jsonEncode({
              'success': false,
              'errors': {'treatment': "Ce type de soin est utilisé dans l'historique des soins."},
            });
      await http.runWithClient(() async {
        await _pump(tester, initialTab: 2);
        await tester.tap(find.byKey(const ValueKey('treatment-menu-5')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Supprimer'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('care-confirm')));
        await tester.pumpAndSettle();
      }, api.client);
      expect(find.text("Ce type de soin est utilisé dans l'historique des soins."), findsOneWidget);
      expect(find.text('Vaccin VHD2'), findsOneWidget);
    });

    testWidgets('history lists the rabbits treated and the next due date', (tester) async {
      final due = DateTime.now().add(const Duration(days: 30));
      final api =
          _CareApi()
            ..treatments = [_treatment(5, 'Vaccin VHD2')]
            ..records = [
              {
                'id': 9,
                'treatment': 5,
                'treatment_name': 'Vaccin VHD2',
                'treatment_category': 'vaccine',
                'rabbits': [1, 2],
                'rabbits_detail': [
                  {'id': 1, 'name': 'Bella', 'tag_number': 'F1', 'gender': 'F'},
                  {'id': 2, 'name': 'Flash', 'tag_number': 'M1', 'gender': 'M'},
                ],
                'date': _iso(DateTime.now()),
                'purpose': 'Prévention VHD',
                'next_due_date': _iso(due),
              },
            ];
      await http.runWithClient(() async {
        await _pump(tester, initialTab: 1);
        expect(find.text('Vaccin VHD2'), findsOneWidget);
        expect(find.text('Motif : Prévention VHD'), findsOneWidget);
        expect(find.text('Bella'), findsOneWidget);
        expect(find.text('Flash'), findsOneWidget);
        expect(find.textContaining('Prochain soin le'), findsOneWidget);
      }, api.client);
    });
  });
}
