import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/rabbit_provider.dart';
import '../theme/colors.dart';
import '../widgets/reminders.dart';

/// Toutes les actions à mener : palpations à faire, mises bas à enregistrer,
/// soins dus. Accessible depuis le rappel de la page d'accueil ("Voir plus").
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RabbitProvider>(
      builder: (context, provider, child) {
        final items = buildReminders(provider);

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Activité'),
          ),
          body: SafeArea(
            child:
                items.isEmpty
                    ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aucune action en attente. Tout est à jour ! 🎉',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh:
                          () => provider.fetchAll(
                            token: context.read<AuthProvider>().token,
                          ),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(18),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder:
                            (_, i) => ReminderCard(
                              key: ValueKey('activity-item-$i'),
                              item: items[i],
                              provider: provider,
                              width: double.infinity,
                            ),
                      ),
                    ),
          ),
        );
      },
    );
  }
}
