import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clap_in/providers/auth_provider.dart';
import 'package:clap_in/providers/rabbit_provider.dart';
import 'package:clap_in/screens/add_rabbit_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR', null));

  testWidgets('the wizard needs a name, then walks through the 3 steps', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => RabbitProvider()..seedForTesting(),
          ),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const MaterialApp(home: AddRabbitScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Étape 1 : photo, nom et date de naissance (pas de bouton Retour)
    expect(find.text('Étape 1/3'), findsOneWidget);
    expect(find.byKey(const ValueKey('photo-frame')), findsOneWidget);
    expect(find.byKey(const ValueKey('birth-date')), findsOneWidget);
    expect(find.byKey(const ValueKey('gender-male')), findsNothing);
    expect(find.byKey(const ValueKey('wizard-back')), findsNothing);

    // Pas de labels, seulement des placeholders
    expect(find.text('Nom du lapin'), findsOneWidget);

    // Sans nom, on reste sur l'étape 1
    await tester.tap(find.byKey(const ValueKey('wizard-next')));
    await tester.pumpAndSettle();
    expect(find.text('Veuillez saisir un nom'), findsOneWidget);
    expect(find.text('Étape 1/3'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Noisette');
    await tester.tap(find.byKey(const ValueKey('wizard-next')));
    await tester.pumpAndSettle();

    // Étape 2 : sexe, race, couleur et parents
    expect(find.text('Parents'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('gender-male')));
    expect(find.text('Père ♂'), findsOneWidget);

    // Bouton Retour : la saisie de l'étape 1 est conservée
    await tester.tap(find.byKey(const ValueKey('wizard-back')));
    await tester.pumpAndSettle();
    expect(find.text('Noisette'), findsOneWidget);

    // Étape 3 : l'emplacement, et le bouton d'enregistrement
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('wizard-next')));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('wizard-save')), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget);
  });
}
