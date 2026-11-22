import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/subscription.dart';
import '../providers/rabbit_provider.dart';
import '../providers/subscription_provider.dart';
import '../theme/colors.dart';
import '../utils/formatters.dart';
import '../widgets/app_ui.dart';
import '../widgets/plan_limit.dart';

/// Ouvre la page de paiement GeniusPay hors de l'app (remplaçable en test).
@visibleForTesting
Future<bool> Function(Uri url) openPaymentPage =
    (url) => launchUrl(url, mode: LaunchMode.externalApplication);

/// Formules d'abonnement : formule en vigueur, nombre de lapins, tarifs et
/// paiement d'un mois (Mobile Money ou carte via GeniusPay).
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with WidgetsBindingObserver {
  String? _payingPlan;
  // Paiement ouvert dans le navigateur, à vérifier au retour dans l'app
  String? _pendingReference;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SubscriptionProvider>().fetch();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingReference != null) {
      checkPendingPayment();
    }
  }

  Future<void> _pay(PlanOffer plan) async {
    setState(() => _payingPlan = plan.code);
    final provider = context.read<SubscriptionProvider>();
    try {
      final checkout = await provider.startCheckout(plan.code);
      _pendingReference = checkout.reference;
      final opened = await openPaymentPage(Uri.parse(checkout.checkoutUrl));
      if (!opened && mounted) {
        showAppSnack(context, "Impossible d'ouvrir la page de paiement.", error: true);
      }
    } on SubscriptionException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _payingPlan = null);
    }
  }

  /// Au retour de la page de paiement : le serveur relit le statut chez GeniusPay.
  @visibleForTesting
  Future<void> checkPendingPayment() async {
    final reference = _pendingReference;
    if (reference == null || _checking) return;
    setState(() => _checking = true);
    final payment = await context.read<SubscriptionProvider>().refreshPayment(
      reference,
    );
    if (!mounted) return;
    setState(() => _checking = false);
    if (payment == null) {
      showAppSnack(context, 'Vérification du paiement impossible, réessayez.', error: true);
      return;
    }
    if (payment.isCompleted) {
      _pendingReference = null;
      final end = context.read<SubscriptionProvider>().status?.periodEnd;
      showAppSnack(
        context,
        end != null
            ? 'Abonnement activé jusqu’au ${formatDate(end)}'
            : 'Abonnement activé',
      );
    } else if (payment.isFailed) {
      _pendingReference = null;
      showAppSnack(context, "Le paiement n'a pas abouti.", error: true);
    } else {
      showAppSnack(
        context,
        'Paiement en attente de confirmation. Il sera pris en compte dès sa validation.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<SubscriptionProvider>().status;
    final count =
        status?.rabbitCount ?? context.watch<RabbitProvider>().rabbits.length;
    final offers = status?.plans ?? PlanOffer.defaults;
    final current = status?.plan ?? 'free';
    final recommended =
        status?.planFor(count).code ??
        offers
            .firstWhere(
              (p) => p.maxRabbits == null || count <= p.maxRabbits!,
              orElse: () => offers.last,
            )
            .code;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(title: const Text('Abonnement')),
      body: RefreshIndicator(
        onRefresh: () => context.read<SubscriptionProvider>().fetch(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _CurrentPlanCard(status: status, count: count),
            if (_pendingReference != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('subscription-check-payment'),
                onPressed: _checking ? null : checkPendingPayment,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(_checking ? 'Vérification…' : "J'ai payé, vérifier"),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Formules',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Le prix dépend du nombre de lapins enregistrés dans votre élevage. '
              'Un paiement couvre 30 jours.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            for (final offer in offers)
              _PlanCard(
                offer: offer,
                range: offer.rangeLabel(offers),
                isCurrent: offer.code == current,
                isRecommended: offer.code == recommended && offer.code != current,
                tooSmall:
                    offer.maxRabbits != null && count > offer.maxRabbits!,
                renew: offer.code == current && (status?.isPaid ?? false),
                paying: _payingPlan == offer.code,
                onPay: _payingPlan == null ? () => _pay(offer) : null,
              ),
            const SizedBox(height: 8),
            const Text(
              'Paiement sécurisé par GeniusPay : Wave, Orange Money, MTN, Moov ou carte bancaire.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  final SubscriptionStatus? status;
  final int count;

  const _CurrentPlanCard({required this.status, required this.count});

  @override
  Widget build(BuildContext context) {
    final s = status;
    final limit = s?.limit;
    final progress = limit == null || limit == 0 ? null : (count / limit).clamp(0.0, 1.0);
    final full = limit != null && count >= limit;
    return Container(
      key: const ValueKey('subscription-current'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.secondaryDark, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Votre formule',
            style: TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
          const SizedBox(height: 2),
          Text(
            s?.planName ?? 'Gratuit',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            limit == null
                ? '$count lapins · illimité'
                : '$count lapins sur $limit autorisés',
            key: const ValueKey('subscription-usage'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            s == null
                ? 'Connectez-vous à internet pour voir votre formule.'
                : s.isPaid && s.periodEnd != null
                ? 'Valable jusqu’au ${formatDate(s.periodEnd!)} (${s.daysLeft} j restants)'
                : full
                ? 'Limite atteinte : choisissez une formule pour ajouter des lapins.'
                : 'Gratuit tant que vous avez moins de 5 lapins.',
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanOffer offer;
  final String range;
  final bool isCurrent;
  final bool isRecommended;
  final bool tooSmall;
  final bool renew;
  final bool paying;
  final VoidCallback? onPay;

  const _PlanCard({
    required this.offer,
    required this.range,
    required this.isCurrent,
    required this.isRecommended,
    required this.tooSmall,
    required this.renew,
    required this.paying,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final highlight = isCurrent || isRecommended;
    return Container(
      key: ValueKey('plan-${offer.code}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight ? AppColors.secondary : AppColors.cardBorder,
          width: highlight ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  offer.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isCurrent)
                const _Badge('Formule actuelle')
              else if (isRecommended)
                const _Badge('Recommandée'),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            range,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: offer.isFree ? 'Gratuit' : formatFcfa(offer.price),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (!offer.isFree)
                  const TextSpan(
                    text: ' / mois',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (!offer.isFree) ...[
            const SizedBox(height: 12),
            if (tooSmall)
              const Text(
                'Vous avez plus de lapins que cette formule n’en permet.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  key: ValueKey('pay-${offer.code}'),
                  onPressed: onPay,
                  child:
                      paying
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : Text(
                            renew
                                ? 'Prolonger de 30 jours · ${formatFcfa(offer.price)}'
                                : 'Payer ${formatFcfa(offer.price)}',
                          ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.secondary,
        ),
      ),
    );
  }
}
