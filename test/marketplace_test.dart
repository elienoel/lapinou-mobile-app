import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:clap_in/models/marketplace_listing.dart';
import 'package:clap_in/providers/auth_provider.dart';
import 'package:clap_in/providers/chat_provider.dart';
import 'package:clap_in/providers/marketplace_provider.dart';
import 'package:clap_in/screens/marketplace_screen.dart';

import 'support/chat_fakes.dart';

Map<String, dynamic> listingJson(
  int id, {
  int seller = 2,
  String title = 'Mâle Néo-Zélandais',
  String type = 'sell',
  String status = 'available',
  String? price = '15000.00',
  String? location = 'Bouaké',
}) => {
  'id': id,
  'seller': seller,
  'seller_name': seller == 1 ? 'Ferme Awa' : 'Ferme Mensah',
  'seller_phone': '+2250700000002',
  'title': title,
  'listing_type': type,
  'description': 'Bon reproducteur, vacciné.',
  'price': price,
  'location': location,
  'photo': null,
  'status': status,
  'created_at': DateTime.now().toUtc().toIso8601String(),
};

/// Faux serveur des annonces : liste, création (multipart), statut, suppression.
class FakeMarket {
  final List<Map<String, dynamic>> listings;
  final requests = <String>[];
  String? lastBody;

  FakeMarket(this.listings);

  MockClient client() => MockClient.streaming((req, bodyStream) async {
    final body = await bodyStream.bytesToString();
    lastBody = body;
    requests.add('${req.method} ${req.url.path}');
    final res = _handle(req.method, req.url, body);
    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
    );
  });

  http.Response _handle(String method, Uri url, String body) {
    final idMatch = RegExp(r'/marketplace/(\d+)/$').firstMatch(url.path);
    if (idMatch == null && method == 'GET') return okResponse(listings);
    if (idMatch == null && method == 'POST') {
      String field(String name) =>
          RegExp('name="$name"\r\n\r\n(.*?)\r\n', dotAll: true)
              .firstMatch(body)
              ?.group(1) ??
          '';
      final created = listingJson(
        99,
        seller: 1,
        title: field('title'),
        type: field('listing_type'),
        price: field('price').isEmpty ? null : field('price'),
        location: field('location'),
      );
      listings.insert(0, created);
      return okResponse(created, status: 201);
    }
    final id = int.parse(idMatch!.group(1)!);
    final i = listings.indexWhere((l) => l['id'] == id);
    if (method == 'PATCH') {
      listings[i] = {...listings[i], ...jsonDecode(body)};
      return okResponse(listings[i]);
    }
    if (method == 'DELETE') {
      listings.removeAt(i);
      return okResponse(null);
    }
    return http.Response('{}', 404);
  }
}

/// Écran de téléphone haut : fiche et formulaire tiennent sans défilement.
void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget marketApp(AuthProvider auth, MarketplaceProvider market) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<MarketplaceProvider>.value(value: market),
        ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
      ],
      child: const MaterialApp(home: MarketplaceScreen()),
    );

void main() {
  test('a listing without price is parsed as negotiable', () {
    final l = MarketplaceListing.fromJson(listingJson(1, price: null, type: 'feed'));
    expect(l.price, isNull);
    expect(l.type, ListingType.feed);
    expect(l.isAvailable, isTrue);
  });

  testWidgets('lists listings, hides sold ones of others, filters by category', (
    tester,
  ) async {
    tallScreen(tester);
    final auth = await loggedInAuth(tester);
    final server = FakeMarket([
      listingJson(1, title: 'Mâle Néo-Zélandais'),
      listingJson(2, title: 'Cages grillagées', type: 'equipment'),
      listingJson(3, title: 'Femelle vendue', status: 'closed'),
    ]);
    final market = MarketplaceProvider(client: server.client())
      ..setToken('tok');

    await tester.pumpWidget(marketApp(auth, market));
    await tester.pumpAndSettle();

    expect(find.text('Mâle Néo-Zélandais'), findsOneWidget);
    expect(find.text('Cages grillagées'), findsOneWidget);
    expect(find.text('Femelle vendue'), findsNothing);
    expect(market.availableCount, 2);

    await tester.tap(find.byKey(const ValueKey('market-filter-equipment')));
    await tester.pumpAndSettle();
    expect(find.text('Mâle Néo-Zélandais'), findsNothing);
    expect(find.text('Cages grillagées'), findsOneWidget);
  });

  testWidgets('publishing a listing sends it and shows it in my listings', (
    tester,
  ) async {
    tallScreen(tester);
    final auth = await loggedInAuth(tester);
    final server = FakeMarket([listingJson(1)]);
    final market = MarketplaceProvider(client: server.client())
      ..setToken('tok');

    await tester.pumpWidget(marketApp(auth, market));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('market-publish')));
    await tester.pumpAndSettle();

    // Titre et description obligatoires
    await tester.tap(find.byKey(const ValueKey('listing-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Donnez un titre à votre annonce.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('listing-type-feed')));
    await tester.enterText(find.byKey(const ValueKey('listing-title')), 'Foin de luzerne');
    await tester.enterText(find.byKey(const ValueKey('listing-price')), '2500');
    await tester.enterText(find.byKey(const ValueKey('listing-location')), 'Yamoussoukro');
    await tester.enterText(
      find.byKey(const ValueKey('listing-description')),
      '50 bottes disponibles',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('listing-submit')));
    await tester.tap(find.byKey(const ValueKey('listing-submit')));
    await tester.pumpAndSettle();

    expect(server.requests, contains('POST /api/community/marketplace/'));
    expect(server.lastBody, contains('name="listing_type"\r\n\r\nfeed'));
    expect(server.lastBody, contains('name="price"\r\n\r\n2500.00'));

    await tester.tap(find.byKey(const ValueKey('market-tab-mine')));
    await tester.pumpAndSettle();
    expect(find.text('Foin de luzerne'), findsOneWidget);
    expect(find.text('Mâle Néo-Zélandais'), findsNothing);
  });

  testWidgets('a buyer sees the contact buttons, not the seller actions', (
    tester,
  ) async {
    tallScreen(tester);
    final auth = await loggedInAuth(tester);
    final market = MarketplaceProvider(
      client: FakeMarket([listingJson(1, seller: 2)]).client(),
    )..setToken('tok');

    await tester.pumpWidget(marketApp(auth, market));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('listing-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('listing-message')), findsOneWidget);
    expect(find.byKey(const ValueKey('listing-call')), findsOneWidget);
    expect(find.byKey(const ValueKey('listing-edit')), findsNothing);
    expect(find.byKey(const ValueKey('listing-status')), findsNothing);
  });

  testWidgets('the seller marks a listing as reserved, then deletes it', (
    tester,
  ) async {
    tallScreen(tester);
    final auth = await loggedInAuth(tester);
    final server = FakeMarket([listingJson(5, seller: 1, title: 'Ma cage')]);
    final market = MarketplaceProvider(client: server.client())
      ..setToken('tok');

    await tester.pumpWidget(marketApp(auth, market));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('listing-5')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('listing-message')), findsNothing);
    await tester.tap(find.text('Réservé'));
    await tester.pumpAndSettle();
    expect(server.requests, contains('PATCH /api/community/marketplace/5/'));
    expect(market.listings.single.status, ListingStatus.reserved);

    await tester.ensureVisible(find.byKey(const ValueKey('listing-delete')));
    await tester.tap(find.byKey(const ValueKey('listing-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('listing-delete-confirm')));
    await tester.pumpAndSettle();

    expect(server.requests, contains('DELETE /api/community/marketplace/5/'));
    expect(market.listings, isEmpty);
    expect(find.text('Ma cage'), findsNothing);
  });
}
