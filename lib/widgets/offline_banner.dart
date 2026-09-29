import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sync_service.dart';

/// Bandeau discret affiché quand des modifications du cheptel attendent encore
/// d'être envoyées au serveur (hors-ligne, ou synchronisation en cours).
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
        final label =
            syncing
                ? 'Synchronisation en cours…'
                : '${sync.pendingCount} modification${sync.pendingCount > 1 ? 's' : ''} en attente de connexion';

        return Container(
          width: double.infinity,
          color: Colors.amber.shade100,
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
                          color: Colors.amber.shade900,
                        )
                        : Icon(
                          Icons.cloud_off_rounded,
                          size: 16,
                          color: Colors.amber.shade900,
                        ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
