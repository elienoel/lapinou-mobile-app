import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/sync_settings_screen.dart';
import '../services/sync_service.dart';

/// Bandeau discret affiché quand des modifications du cheptel attendent encore
/// d'être envoyées au serveur (hors-ligne, synchronisation en cours, ou erreur).
/// Un appui ouvre l'écran Synchronisation (Paramètres) pour le détail.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncService>(
      builder: (context, sync, _) {
        if (sync.pendingCount == 0 && sync.status != SyncStatus.syncing) {
          return const SizedBox.shrink();
        }
        final syncing = sync.status == SyncStatus.syncing;
        final hasError = sync.status == SyncStatus.error;
        final label =
            syncing
                ? 'Synchronisation en cours…'
                : hasError
                ? (sync.lastError ?? 'Erreur de synchronisation')
                : '${sync.pendingCount} modification${sync.pendingCount > 1 ? 's' : ''} en attente de connexion';
        final color = hasError ? Colors.red : Colors.amber;

        return InkWell(
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncSettingsScreen()),
              ),
          child: Container(
            width: double.infinity,
            color: color.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child:
                      syncing
                          ? CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color.shade900,
                          )
                          : Icon(
                            hasError ? Icons.error_outline : Icons.cloud_off_rounded,
                            size: 16,
                            color: color.shade900,
                          ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color.shade900,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: color.shade900),
              ],
            ),
          ),
        );
      },
    );
  }
}
