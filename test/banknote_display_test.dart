import 'package:flutter_test/flutter_test.dart';
import 'package:clap_in/widgets/banknote_display.dart';

void main() {
  group('breakdownCfaAmount', () {
    test('montants négatifs ou nuls retournent une liste vide', () {
      expect(breakdownCfaAmount(0), isEmpty);
      expect(breakdownCfaAmount(-500), isEmpty);
    });

    test('15 000 FCFA donne 1 billet de 10 000 et 1 de 5 000', () {
      final notes = breakdownCfaAmount(15000);
      expect(notes, [CfaBanknote.f10000, CfaBanknote.f5000]);
    });

    test('40 000 FCFA donne 4 billets de 10 000', () {
      final notes = breakdownCfaAmount(40000);
      expect(notes, [
        CfaBanknote.f10000,
        CfaBanknote.f10000,
        CfaBanknote.f10000,
        CfaBanknote.f10000,
      ]);
    });

    test('12 000 FCFA donne 1 billet de 10 000 et 1 de 2 000', () {
      final notes = breakdownCfaAmount(12000);
      expect(notes, [CfaBanknote.f10000, CfaBanknote.f2000]);
    });

    test('17 500 FCFA donne 10 000, 5 000, 2 000 et 500', () {
      final notes = breakdownCfaAmount(17500);
      expect(notes, [
        CfaBanknote.f10000,
        CfaBanknote.f5000,
        CfaBanknote.f2000,
        CfaBanknote.f500,
      ]);
    });

    test('montant > 50 000 FCFA (ex: 60 000) donne 1 seul billet de 10 000', () {
      final notes = breakdownCfaAmount(60000);
      expect(notes, [CfaBanknote.f10000]);

      final notesBig = breakdownCfaAmount(250000);
      expect(notesBig, [CfaBanknote.f10000]);
    });

    test('50 000 FCFA est la limite (5 billets de 10 000)', () {
      final notes = breakdownCfaAmount(50000);
      expect(notes.length, 5);
      expect(notes.every((n) => n == CfaBanknote.f10000), isTrue);
    });
  });
}
