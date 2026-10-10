import 'package:intl/intl.dart';

/// Devise d'affichage des montants. Le choix ne convertit rien : les montants saisis
/// restent tels quels, seul leur libellé (symbole, décimales) change.
class AppCurrency {
  final String code;
  final String symbol;
  final String name;

  /// Nombre de décimales usuel (0 pour les francs CFA, guinéen, congolais)
  final int decimals;

  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.name,
    this.decimals = 2,
  });

  /// Montant lisible, ex. « 1 250,50 € » ou « -125 000 FCFA ».
  /// [showSign] ajoute « + » aux montants positifs ; [decimals] remplace le défaut de la devise.
  String format(double amount, {bool showSign = false, int? decimals}) {
    final digits = decimals ?? this.decimals;
    final formatter = NumberFormat.decimalPatternDigits(
      locale: 'fr_FR',
      decimalDigits: digits,
    );
    // Éviter « -0 » quand l'arrondi ramène le montant à zéro
    final rounded = double.parse(amount.toStringAsFixed(digits));
    final sign = rounded < 0 ? '-' : (showSign && rounded > 0 ? '+' : '');
    return '$sign${formatter.format(rounded.abs())} $symbol';
  }
}

const AppCurrency kDefaultCurrency = AppCurrency(
  code: 'EUR',
  symbol: '€',
  name: 'Euro',
);

/// Liste identique à celle acceptée par le serveur.
const List<AppCurrency> kCurrencies = [
  kDefaultCurrency,
  AppCurrency(
    code: 'XOF',
    symbol: 'FCFA',
    name: 'Franc CFA (BCEAO)',
    decimals: 0,
  ),
  AppCurrency(
    code: 'XAF',
    symbol: 'FCFA',
    name: 'Franc CFA (BEAC)',
    decimals: 0,
  ),
  AppCurrency(code: 'USD', symbol: r'$', name: 'Dollar américain'),
  AppCurrency(code: 'GBP', symbol: '£', name: 'Livre sterling'),
  AppCurrency(code: 'CHF', symbol: 'CHF', name: 'Franc suisse'),
  AppCurrency(code: 'CAD', symbol: r'CA$', name: 'Dollar canadien'),
  AppCurrency(code: 'MAD', symbol: 'DH', name: 'Dirham marocain'),
  AppCurrency(code: 'TND', symbol: 'DT', name: 'Dinar tunisien'),
  AppCurrency(code: 'DZD', symbol: 'DA', name: 'Dinar algérien'),
  AppCurrency(code: 'NGN', symbol: '₦', name: 'Naira nigérian'),
  AppCurrency(code: 'GHS', symbol: 'GH₵', name: 'Cedi ghanéen'),
  AppCurrency(code: 'GNF', symbol: 'FG', name: 'Franc guinéen', decimals: 0),
  AppCurrency(code: 'CDF', symbol: 'FC', name: 'Franc congolais', decimals: 0),
];

/// Devise correspondant à un code ; l'euro par défaut si le code est inconnu ou absent.
AppCurrency currencyByCode(String? code) {
  for (final c in kCurrencies) {
    if (c.code == code) return c;
  }
  return kDefaultCurrency;
}
