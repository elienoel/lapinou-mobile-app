/// Formule d'abonnement : le prix dépend du nombre de fiches lapins.
class PlanOffer {
  final String code;
  final String name;

  /// Prix mensuel en F CFA (0 = gratuit)
  final int price;

  /// Nombre maximum de fiches lapins ; null = illimité
  final int? maxRabbits;

  const PlanOffer({
    required this.code,
    required this.name,
    required this.price,
    this.maxRabbits,
  });

  bool get isFree => price == 0;

  /// « Jusqu'à 4 lapins », « De 5 à 10 lapins », « Plus de 10 lapins »
  String rangeLabel(List<PlanOffer> all) {
    final index = all.indexWhere((p) => p.code == code);
    final previous = index > 0 ? all[index - 1].maxRabbits : null;
    if (maxRabbits == null) {
      return previous == null ? 'Lapins illimités' : 'Plus de $previous lapins';
    }
    if (previous == null) return "Jusqu'à $maxRabbits lapins";
    return 'De ${previous + 1} à $maxRabbits lapins';
  }

  factory PlanOffer.fromJson(Map<String, dynamic> json) => PlanOffer(
    code: json['code'] as String,
    name: json['name'] as String? ?? '',
    price: (json['price'] as num?)?.toInt() ?? 0,
    maxRabbits: (json['max_rabbits'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'price': price,
    'max_rabbits': maxRabbits,
  };

  /// Tarifs affichés tant que le serveur n'a pas répondu (mêmes valeurs que le backend).
  static const defaults = [
    PlanOffer(code: 'free', name: 'Gratuit', price: 0, maxRabbits: 4),
    PlanOffer(code: 'breeder', name: 'Éleveur', price: 1200, maxRabbits: 10),
    PlanOffer(code: 'pro', name: 'Pro', price: 2500),
  ];
}

/// Formule en vigueur de l'éleveur, telle que calculée par le serveur.
class SubscriptionStatus {
  final String plan;
  final String planName;

  /// Fiches lapins autorisées ; null = illimité
  final int? limit;
  final int rabbitCount;
  final DateTime? periodEnd;
  final int daysLeft;

  /// Formule minimale pour le nombre actuel de fiches
  final String requiredPlan;
  final List<PlanOffer> plans;

  const SubscriptionStatus({
    required this.plan,
    required this.planName,
    required this.limit,
    required this.rabbitCount,
    this.periodEnd,
    this.daysLeft = 0,
    required this.requiredPlan,
    this.plans = PlanOffer.defaults,
  });

  bool get isPaid => plan != 'free';

  /// Vrai si [count] fiches existantes + [adding] nouvelles tiennent dans la formule.
  bool canAdd(int count, [int adding = 1]) =>
      limit == null || count + adding <= limit!;

  PlanOffer offer(String code) => plans.firstWhere(
    (p) => p.code == code,
    orElse: () => PlanOffer.defaults.firstWhere((p) => p.code == code),
  );

  /// Formule minimale pour [count] fiches.
  PlanOffer planFor(int count) => plans.firstWhere(
    (p) => p.maxRabbits == null || count <= p.maxRabbits!,
    orElse: () => plans.last,
  );

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    final list = json['plans'];
    return SubscriptionStatus(
      plan: json['plan'] as String? ?? 'free',
      planName: json['plan_name'] as String? ?? 'Gratuit',
      limit: (json['limit'] as num?)?.toInt(),
      rabbitCount: (json['rabbit_count'] as num?)?.toInt() ?? 0,
      periodEnd:
          json['current_period_end'] == null
              ? null
              : DateTime.tryParse(json['current_period_end'].toString())?.toLocal(),
      daysLeft: (json['days_left'] as num?)?.toInt() ?? 0,
      requiredPlan: json['required_plan'] as String? ?? 'free',
      plans:
          list is List && list.isNotEmpty
              ? [
                for (final p in list)
                  PlanOffer.fromJson(Map<String, dynamic>.from(p as Map)),
              ]
              : PlanOffer.defaults,
    );
  }

  Map<String, dynamic> toJson() => {
    'plan': plan,
    'plan_name': planName,
    'limit': limit,
    'rabbit_count': rabbitCount,
    'current_period_end': periodEnd?.toUtc().toIso8601String(),
    'days_left': daysLeft,
    'required_plan': requiredPlan,
    'plans': plans.map((p) => p.toJson()).toList(),
  };
}

/// Paiement d'une période, démarré depuis l'app.
class SubscriptionCheckout {
  final String reference;
  final String checkoutUrl;
  final String status;

  const SubscriptionCheckout({
    required this.reference,
    required this.checkoutUrl,
    required this.status,
  });

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  factory SubscriptionCheckout.fromJson(Map<String, dynamic> json) =>
      SubscriptionCheckout(
        reference: json['reference']?.toString() ?? '',
        checkoutUrl: json['checkout_url']?.toString() ?? '',
        status: json['status']?.toString() ?? 'pending',
      );
}
