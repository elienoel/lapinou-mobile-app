import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/sync_service.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';

/// État de la synchronisation hors-ligne : file d'attente, dernière synchro,
/// dernière erreur, et un bouton pour forcer une nouvelle tentative.
class SyncSettingsScreen extends StatelessWidget {
  const SyncSettingsScreen({super.key});

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return 'il y a ${diff.inDays} j';
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final syncing = sync.status == SyncStatus.syncing;
    final hasError = sync.status == SyncStatus.error;
    final upToDate = sync.pendingCount == 0 && !syncing && !hasError;

    final Color statusColor =
        hasError
            ? Colors.red.shade700
            : (upToDate ? AppColors.primary : Colors.amber.shade900);
    final IconData statusIcon =
        syncing
            ? Icons.sync
            : hasError
            ? Icons.error_outline
            : (upToDate ? Icons.cloud_done_outlined : Icons.cloud_off_rounded);
    final String statusLabel =
        syncing
            ? 'Synchronisation en cours…'
            : hasError
            ? 'Erreur de synchronisation'
            : (upToDate
                ? 'Tout est synchronisé'
                : '${sync.pendingCount} modification${sync.pendingCount > 1 ? 's' : ''} en attente');

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        title: const Text(
          'Synchronisation',
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
              "Vos modifications sont d'abord enregistrées sur l'appareil, puis "
              "envoyées au serveur dès qu'une connexion est disponible.",
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            syncing
                                ? CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: statusColor,
                                )
                                : Icon(statusIcon, color: statusColor, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          statusLabel,
                          key: const ValueKey('sync-status-label'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    sync.lastSyncedAt != null
                        ? 'Dernière synchronisation : ${_relativeTime(sync.lastSyncedAt!)}'
                        : 'Dernière synchronisation : jamais',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (hasError && sync.lastError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        sync.lastError!,
                        key: const ValueKey('sync-error-detail'),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: syncing ? null : () => sync.syncNow(),
                      icon: const Icon(Icons.sync, size: 18),
                      label: Text(
                        syncing ? 'Synchronisation…' : 'Synchroniser maintenant',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
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
}
