import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/subscription.dart';
import '../providers/rabbit_provider.dart';
import '../providers/subscription_provider.dart';
import '../screens/subscription_screen.dart';
import '../theme/colors.dart';
import 'app_ui.dart';

/// « 1 200 F »
String formatFcfa(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return '$buffer F';
}

/// Vérifie que [adding] nouvelles fiches lapins tiennent dans la formule de
/// l'éleveur. Sinon, explique la limite et propose l'écran Abonnement ; renvoie
/// false pour annuler l'ajout. Sans formule connue (jamais synchronisée), laisse
/// passer : le serveur tranchera.
Future<bool> guardRabbitQuota(BuildContext context, int adding) async {
  if (adding <= 0) return true;
  SubscriptionStatus? status;
  try {
    status = context.read<SubscriptionProvider>().status;
  } on ProviderNotFoundException {
    return true;
  }
  if (status == null) return true;
  final count = context.read<RabbitProvider>().rabbits.length;
  if (status.canAdd(count, adding)) return true;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => PlanLimitSheet(status: status!, count: count, adding: adding),
  );
  return false;
}

class PlanLimitSheet extends StatelessWidget {
  final SubscriptionStatus status;
  final int count;
  final int adding;

  const PlanLimitSheet({
    super.key,
    required this.status,
    required this.count,
    required this.adding,
  });

  @override
  Widget build(BuildContext context) {
    final current = status.offer(status.plan);
    final needed = status.planFor(count + adding);
    return SheetBody(
      children: [
        const Text(
          'Limite de votre abonnement atteinte',
          key: ValueKey('plan-limit-title'),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Votre formule ${current.name} permet ${status.limit} lapins et vous en avez $count. '
          'Passez à la formule ${needed.name} (${formatFcfa(needed.price)} par mois) '
          'pour en ajouter.',
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Vos lapins restent consultables et modifiables.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 18),
        SubmitButton(
          key: const ValueKey('plan-limit-upgrade'),
          label: 'Voir les abonnements',
          saving: false,
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            );
          },
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
        ),
      ],
    );
  }
}
