import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:intl/intl.dart';

import '../services/local_database.dart';
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
                                : Icon(
                                  statusIcon,
                                  color: statusColor,
                                  size: 22,
                                ),
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
                        syncing
                            ? 'Synchronisation…'
                            : 'Synchroniser maintenant',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _actionsCard(
              title: 'À synchroniser',
              subtitle:
                  sync.pendingActions.isEmpty
                      ? 'Rien en attente : tout est envoyé au serveur.'
                      : 'Ces actions ne sont pas encore envoyées. Elles partiront dès la connexion.',
              entries: sync.pendingActions,
              highlight: true,
              emptyText: 'Aucune action en attente.',
            ),
            const SizedBox(height: 16),
            _actionsCard(
              title: 'Historique',
              subtitle:
                  'Toutes les actions faites sur cet appareil, les plus récentes d\'abord.',
              entries: sync.history,
              highlight: false,
              emptyText: 'Aucune action enregistrée.',
            ),
            if (sync.rejected.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modifications refusées par le serveur',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ces éléments ne sont pas enregistrés dans votre élevage en ligne. '
                      'Corrigez-les puis relancez l’envoi.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    for (final r in sync.rejected) ...[
                      const Divider(height: 20),
                      Text(
                        '${r.entityLabel} : ${r.name}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r.error,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        key: const ValueKey('sync-retry-rejected'),
                        onPressed: syncing ? null : () => sync.retryRejected(),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Relancer l’envoi'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionsCard({
    required String title,
    required String subtitle,
    required List<ActionLogEntry> entries,
    required bool highlight,
    required String emptyText,
  }) {
    final accent = highlight ? Colors.amber.shade900 : AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            highlight && entries.isNotEmpty
                ? Colors.amber.shade50
                : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color:
              highlight && entries.isNotEmpty
                  ? Colors.amber.shade400
                  : AppColors.cardBorder,
          width: highlight && entries.isNotEmpty ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              if (highlight && entries.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${entries.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                emptyText,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            for (final a in entries) ...[
              const Divider(height: 14),
              _actionRow(a),
            ],
        ],
      ),
    );
  }

  Widget _actionRow(ActionLogEntry a) {
    final (label, color) = switch (a.status) {
      'pending' => ('En attente', Colors.amber.shade900),
      'sent' => ('Envoyée', AppColors.primary),
      'rejected' => ('Refusée', Colors.red.shade700),
      _ => ('Annulée', AppColors.textSecondary),
    };
    final op = switch (a.operation) {
      'create' => 'Création',
      'update' => 'Modification',
      _ => 'Suppression',
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${a.label} · ${_entityLabel(a.entity)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '$op · ${DateFormat('dd/MM/yyyy HH:mm').format(a.updatedAt)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              if (a.error != null)
                Text(
                  a.error!,
                  style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  String _entityLabel(SyncEntity e) => switch (e) {
    SyncEntity.rabbit => 'Lapin',
    SyncEntity.cage => 'Cage',
    SyncEntity.mating => 'Accouplement',
    SyncEntity.litter => 'Mise bas',
    SyncEntity.careTreatment => 'Type de soin',
    SyncEntity.careRecord => 'Soin',
    SyncEntity.careEvent => 'Suivi',
    SyncEntity.finance => 'Transaction',
  };
}
