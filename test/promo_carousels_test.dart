import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clap_in/providers/pharmacy_provider.dart';
import 'package:clap_in/providers/promotions_provider.dart';
import 'package:clap_in/screens/pharmacy_screen.dart';
import 'package:clap_in/widgets/promo_carousels.dart';

Map<String, dynamic> slide(int id, {String link = 'none', String? screen}) => {
  'id': id,
  'image': 'https://api.test/media/promotions/$id.jpg',
  'title': 'Annonce $id',
  'link_type': link,
  'target_screen': screen ?? '',
  'external_url': '',
};

http.Client server(List carousels) => MockClient(
  (_) async => http.Response(
    jsonEncode({'success': true, 'data': carousels}),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  ),
);

Widget app(PromotionsProvider promos) => MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: promos),
    ChangeNotifierProvider(create: (_) => PharmacyProvider()),
  ],
  child: const MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: PromoCarousels())),
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // GIF 1x1 en mémoire : pas de réseau en test
    promoImageProvider = (_) => MemoryImage(base64Decode(
        'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7'));
  });

  test('keeps the server order, drops carousels without images and caches', () async {
    final promos = PromotionsProvider(
      client: server([
        {'id': 2, 'name': 'Premier', 'slides': [slide(5), slide(4)]},
        {'id': 3, 'name': 'Vide', 'slides': []},
        {'id': 1, 'name': 'Second', 'slides': [slide(9)]},
      ]),
    );
    await promos.fetchCarousels();

    expect(promos.carousels.map((c) => c.name), ['Premier', 'Second']);
    expect(promos.carousels.first.slides.map((s) => s.id), [5, 4]);

    // Hors ligne au démarrage suivant : le cache est affiché
    final offline = PromotionsProvider(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await offline.fetchCarousels();
    expect(offline.carousels.map((c) => c.name), ['Premier', 'Second']);
  });

  testWidgets('nothing is shown without active ads', (tester) async {
    final promos = PromotionsProvider(client: server([]));
    await tester.pumpWidget(app(promos));
    await promos.fetchCarousels();
    await tester.pump();
    expect(find.byType(PromoCarouselView), findsNothing);
  });

  testWidgets('slides auto-advance and a tap opens the linked screen', (tester) async {
    final promos = PromotionsProvider(
      client: server([
        {
          'id': 1,
          'name': 'Accueil',
          'slides': [slide(1, link: 'internal', screen: 'pharmacy'), slide(2)],
        },
      ]),
    );
    await tester.pumpWidget(app(promos));
    await tester.runAsync(promos.fetchCarousels);
    await tester.pump();

    expect(find.byType(PromoCarouselView), findsOneWidget);
    final page = find.byType(PageView);
    expect(tester.widget<PageView>(page).controller!.page, 0);

    // Défilement automatique après 5 s
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.widget<PageView>(page).controller!.page, 1);

    // Retour à la première, qui mène à la pharmacie
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.widget<PageView>(page).controller!.page, 0);

    await tester.tap(page);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PharmacyScreen), findsOneWidget);
  });
}
