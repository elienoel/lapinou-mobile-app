import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/currency.dart';
import '../providers/auth_provider.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';

/// Choix de la devise d'affichage des montants.
class CurrencySettingsScreen extends StatelessWidget {
  const CurrencySettingsScreen({super.key});

  Future<void> _select(BuildContext context, AppCurrency currency) async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (auth.currency.code == currency.code) return;

    final error = await auth.updateCurrency(currency.code);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error ?? 'Devise : ${currency.name} (${currency.symbol})',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final current = context.watch<AuthProvider>().currency;

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        title: const Text(
          'Devise',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const Text(
              "Utilisée pour afficher vos ventes, dépenses et le solde de votre élevage. "
              "Les montants déjà saisis ne sont pas convertis : seul l'affichage change.",
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.primarySoftBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Aperçu : ',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  Expanded(
                    child: Text(
                      current.format(45000, showSign: true),
                      key: const ValueKey('currency-preview'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < kCurrencies.length; i++) ...[
                    _tile(
                      context,
                      kCurrencies[i],
                      selected: kCurrencies[i].code == current.code,
                    ),
                    if (i < kCurrencies.length - 1)
                      const Divider(
                        height: 1,
                        indent: 72,
                        color: Color(0xFFEDEFED),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, AppCurrency c, {required bool selected}) {
    return ListTile(
      key: ValueKey('currency-${c.code}'),
      onTap: () => _select(context, c),
      leading: Container(
        width: 44,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.primarySoft,
          border: Border.all(color: AppColors.primary),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          c.symbol,
          style: TextStyle(
            fontSize: c.symbol.length > 3 ? 11 : 14,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppColors.primary,
          ),
        ),
      ),
      title: Text(
        c.name,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      subtitle: Text(c.code),
      trailing:
          selected
              ? const Icon(Icons.check_circle, color: AppColors.primary)
              : const Icon(
                Icons.radio_button_unchecked,
                color: AppColors.textMuted,
              ),
    );
  }
}
