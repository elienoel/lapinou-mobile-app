import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/sync_service.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import 'category_settings_screen.dart';
import 'currency_settings_screen.dart';
import 'sync_settings_screen.dart';

/// Menu des paramètres de l'application.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final syncSubtitle =
        sync.status == SyncStatus.syncing
            ? 'Synchronisation en cours…'
            : sync.status == SyncStatus.error
            ? 'Erreur de synchronisation'
            : sync.pendingCount > 0
            ? '${sync.pendingCount} en attente'
            : 'À jour';

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        title: const Text(
          'Paramètres',
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
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  _tile(
                    context,
                    key: const ValueKey('settings-currency'),
                    icon: Icons.payments_outlined,
                    title: 'Devise',
                    subtitle: 'Unité utilisée pour vos ventes et dépenses',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CurrencySettingsScreen(),
                          ),
                        ),
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFEDEFED)),
                  _tile(
                    context,
                    key: const ValueKey('settings-categories'),
                    icon: Icons.sell_outlined,
                    title: 'Catégories',
                    subtitle: 'Catégories de dépenses et de revenus',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CategorySettingsScreen(),
                          ),
                        ),
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFEDEFED)),
                  _tile(
                    context,
                    key: const ValueKey('settings-sync'),
                    icon: Icons.sync,
                    title: 'Synchronisation',
                    subtitle: syncSubtitle,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SyncSettingsScreen(),
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      key: key,
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.5)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
    );
  }
}
