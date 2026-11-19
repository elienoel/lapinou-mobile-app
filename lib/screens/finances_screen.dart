import '../utils/formatters.dart';
import '../widgets/app_ui.dart';
import '../widgets/banknote_display.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/currency.dart';
import '../models/finance_period.dart';
import '../models/finance_transaction.dart';
import '../providers/auth_provider.dart';
import '../providers/category_provider.dart';
import '../providers/rabbit_provider.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import '../services/validators.dart';

const String _addCategoryValue = '__add_category__';

class FinancesScreen extends StatefulWidget {
  final int initialFilterIndex; // 0: Tout, 1: Dépenses, 2: Ventes

  const FinancesScreen({super.key, this.initialFilterIndex = 0});

  @override
  State<FinancesScreen> createState() => _FinancesScreenState();
}

class _FinancesScreenState extends State<FinancesScreen> {
  late int _selectedFilterIndex;
  // Par défaut : le mois en cours
  FinancePeriod _period = FinancePeriod.thisMonth();

  @override
  void initState() {
    super.initState();
    _selectedFilterIndex = widget.initialFilterIndex;
  }

  /// Ouvre le choix d'une période libre : tout l'historique, une année, ou
  /// une plage de dates au choix.
  Future<void> _openPeriodSheet(List<FinanceTransaction> finances) async {
    final picked = await showModalBottomSheet<FinancePeriod>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) =>
              _PeriodSheet(current: _period, firstYear: _firstYear(finances)),
    );
    if (picked != null && mounted) setState(() => _period = picked);
  }

  /// Année de la plus ancienne transaction (au moins 2 ans proposés).
  static int _firstYear(List<FinanceTransaction> finances) {
    var year = DateTime.now().year - 2;
    for (final f in finances) {
      if (f.date.year < year) year = f.date.year;
    }
    return year;
  }

  /// Mois proposés : du mois en cours jusqu'à celui de la plus ancienne
  /// transaction (au moins 12 mois).
  static List<FinancePeriod> _months(List<FinanceTransaction> finances) {
    final now = DateTime.now();
    var count = 12;
    for (final f in finances) {
      final back = (now.year - f.date.year) * 12 + now.month - f.date.month + 1;
      if (back > count) count = back;
    }
    return FinancePeriod.recentMonths(count, now);
  }

  /// Filtre de la page : le bouton « Filtrer » (période libre), puis les mois,
  /// du plus récent au plus ancien.
  Widget _buildPeriodBar(List<FinanceTransaction> finances) {
    final isMonth = _period.kind == FinancePeriodKind.month;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _periodChip(
            key: const ValueKey('period-filter'),
            label: isMonth ? 'Filtrer' : _period.label,
            icon: Icons.tune_rounded,
            selected: !isMonth,
            onTap: () => _openPeriodSheet(finances),
          ),
          const SizedBox(width: 8),
          for (final month in _months(finances)) ...[
            _periodChip(
              key: ValueKey(
                'period-month-${month.start!.year}-${month.start!.month}',
              ),
              label: month.label,
              selected: _period == month,
              onTap: () => setState(() => _period = month),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _periodChip({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final fg = selected ? Colors.white : AppColors.textSecondary;
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionForm(
    BuildContext context,
    RabbitProvider provider,
    bool isIncome, {
    FinanceTransaction? existing,
  }) {
    final isEditing = existing != null;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final initialAmountStr =
        existing != null
            ? (existing.amount % 1 == 0
                ? existing.amount.toInt().toString()
                : existing.amount.toString())
            : '';
    final amountController = TextEditingController(text: initialAmountStr);
    final notesController = TextEditingController(text: existing?.notes ?? '');
    final currency = context.read<AuthProvider>().currency;
    final categoryType =
        isIncome ? TransactionType.income : TransactionType.expense;
    final categories = context.read<CategoryProvider>();
    var categoryOptions = categories.categoriesFor(categoryType);
    var selectedCategory =
        existing != null && categoryOptions.contains(existing.category)
            ? existing.category
            : (categoryOptions.isNotEmpty ? categoryOptions.first : null);
    // La date vaut aujourd'hui par défaut ; on peut la reculer pour une saisie a posteriori
    final now = DateTime.now();
    var txDate =
        existing != null
            ? DateTime(
              existing.date.year,
              existing.date.month,
              existing.date.day,
            )
            : DateTime(now.year, now.month, now.day);

    double parsedAmount =
        double.tryParse(initialAmountStr.replaceAll(',', '.')) ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder:
              (ctx, setSheetState) => Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              isEditing
                                  ? (isIncome
                                      ? 'Modifier la Vente'
                                      : 'Modifier la Dépense')
                                  : (isIncome
                                      ? 'Enregistrer une Vente'
                                      : 'Enregistrer une Dépense'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isIncome
                                      ? AppColors.statusActiveBg
                                      : AppColors.statusAlertBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isIncome ? 'Recette (+)' : 'Dépense (-)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color:
                                    isIncome
                                        ? AppColors.statusActiveText
                                        : Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Label et input: Intitulé
                      const Text(
                        'Intitulé *',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'Intitulé *',
                          hintText:
                              isIncome
                                  ? 'Ex: Vente jeune mâle Fauve'
                                  : 'Ex: Sac granulés 25kg, Paille...',
                          filled: true,
                          fillColor: const Color(0xFFF7F8FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Illustration des billets en fonction du montant saisi
                      BanknoteAmountIllustration(
                        amount: parsedAmount,
                        isIncome: isIncome,
                      ),
                      const SizedBox(height: 12),

                      // Grand champ montant sans bordure
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Montant (${currency.symbol}) *',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '${currency.symbol} ',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        isIncome
                                            ? AppColors.primary
                                            : Colors.orange.shade800,
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: amountController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    autofocus: !isEditing,
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          isIncome
                                              ? AppColors.primary
                                              : Colors.orange.shade900,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Montant (${currency.symbol}) *',
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      filled: false,
                                      contentPadding: EdgeInsets.zero,
                                      hintText:
                                          currency.decimals == 0
                                              ? '0'
                                              : '0.00',
                                      hintStyle: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    onChanged: (val) {
                                      final v =
                                          double.tryParse(
                                            val.replaceAll(',', '.'),
                                          ) ??
                                          0.0;
                                      setSheetState(() => parsedAmount = v);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Label et input: Date
                      const Text(
                        'Date *',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        key: const ValueKey('tx-date'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: txDate,
                            firstDate: DateTime(now.year - 10),
                            lastDate: DateTime(now.year, now.month, now.day),
                          );
                          if (picked != null) {
                            setSheetState(() => txDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F8FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Text(
                                formatDate(txDate),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Label et dropdown: Catégorie
                      const Text(
                        'Catégorie',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        key: const ValueKey('tx-category'),
                        isExpanded: true,
                        value: selectedCategory,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF7F8FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                        items: [
                          for (final c in categoryOptions)
                            DropdownMenuItem(value: c, child: Text(c)),
                          const DropdownMenuItem(
                            value: _addCategoryValue,
                            child: Text(
                              '+ Ajouter une catégorie…',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) async {
                          if (val == _addCategoryValue) {
                            final controller = TextEditingController();
                            final confirmed = await showDialog<bool>(
                              context: ctx,
                              builder:
                                  (dialogCtx) => AlertDialog(
                                    title: Text(
                                      isIncome
                                          ? 'Nouvelle catégorie de revenu'
                                          : 'Nouvelle catégorie de dépense',
                                    ),
                                    content: TextField(
                                      controller: controller,
                                      autofocus: true,
                                      decoration: const InputDecoration(
                                        hintText: 'Ex: Location de matériel',
                                      ),
                                      onSubmitted:
                                          (_) => Navigator.pop(dialogCtx, true),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () =>
                                                Navigator.pop(dialogCtx, false),
                                        child: const Text('Annuler'),
                                      ),
                                      ElevatedButton(
                                        onPressed:
                                            () =>
                                                Navigator.pop(dialogCtx, true),
                                        child: const Text('Ajouter'),
                                      ),
                                    ],
                                  ),
                            );
                            if (confirmed == true &&
                                controller.text.trim().isNotEmpty) {
                              final added = await categories.addCategory(
                                categoryType,
                                controller.text.trim(),
                              );
                              setSheetState(() {
                                categoryOptions = categories.categoriesFor(
                                  categoryType,
                                );
                                selectedCategory = added;
                              });
                            }
                            return;
                          }
                          setSheetState(() => selectedCategory = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Label et input: Notes & Références
                      const Text(
                        'Notes & Références (optionnel)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: notesController,
                        decoration: InputDecoration(
                          hintText: 'Nom de l\'acheteur, facture...',
                          filled: true,
                          fillColor: const Color(0xFFF7F8FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () async {
                            final title = titleController.text.trim();
                            final amount =
                                double.tryParse(
                                  amountController.text.replaceAll(',', '.'),
                                ) ??
                                0.0;

                            final amountError = Validators.amount(amount);
                            if (amountError != null) {
                              showAppSnack(context, amountError, error: true);
                              return;
                            }
                            if (title.isNotEmpty) {
                              final tx = FinanceTransaction(
                                id:
                                    existing?.id ??
                                    'fin-${DateTime.now().millisecondsSinceEpoch}',
                                type:
                                    isIncome
                                        ? TransactionType.income
                                        : TransactionType.expense,
                                title: title,
                                amount: amount,
                                date: txDate,
                                category:
                                    selectedCategory ??
                                    (isIncome ? 'Vente' : 'Dépense'),
                                notes:
                                    notesController.text.trim().isEmpty
                                        ? null
                                        : notesController.text.trim(),
                              );
                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(ctx);
                              if (isEditing) {
                                await provider.updateFinanceTransaction(tx);
                              } else {
                                await provider.addFinanceTransaction(tx);
                              }
                              navigator.pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEditing
                                        ? 'Modifications enregistrées.'
                                        : (isIncome
                                            ? 'Vente de ${currency.format(amount)} enregistrée !'
                                            : 'Dépense de ${currency.format(amount)} enregistrée.'),
                                  ),
                                  backgroundColor:
                                      isIncome
                                          ? AppColors.primary
                                          : Colors.orange.shade800,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isIncome
                                    ? AppColors.primary
                                    : Colors.orange.shade800,
                          ),
                          child: Text(
                            isEditing
                                ? 'Enregistrer les modifications'
                                : (isIncome
                                    ? 'Valider la Vente (+)'
                                    : 'Valider la Dépense (-)'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      if (isEditing) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          key: const ValueKey('tx-delete'),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(ctx);
                            final ok = await confirmAction(
                              ctx,
                              title: 'Supprimer cette transaction ?',
                              message:
                                  '« ${existing.title} » sera retiré des totaux. Cette action est définitive.',
                              destructive: true,
                            );
                            if (ok != true) return;
                            await provider.deleteFinanceTransaction(
                              existing.id,
                            );
                            navigator.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Transaction supprimée.'),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.red.shade700,
                          ),
                          label: Text(
                            'Supprimer',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RabbitProvider>(
      builder: (context, provider, child) {
        // Tout (totaux, compteurs, liste) est calculé sur la période choisie
        final inPeriod =
            provider.finances.where((f) => _period.contains(f.date)).toList();
        final totals = FinanceTotals.of(inPeriod);
        final totalIncome = totals.income;
        final totalExpense = totals.expense;
        final balance = totals.balance;
        final currency = context.watch<AuthProvider>().currency;

        List<FinanceTransaction> filteredList = inPeriod;
        if (_selectedFilterIndex == 1) {
          filteredList = inPeriod.where((f) => !f.isIncome).toList();
        } else if (_selectedFilterIndex == 2) {
          filteredList = inPeriod.where((f) => f.isIncome).toList();
        }
        // Les plus récentes d'abord (une saisie a posteriori garde sa vraie place)
        filteredList = [...filteredList]
          ..sort((a, b) => b.date.compareTo(a.date));

        String pageTitle = 'Comptabilité du Clapier';
        if (_selectedFilterIndex == 1) pageTitle = 'Dépenses du Clapier';
        if (_selectedFilterIndex == 2) pageTitle = 'Ventes & Recettes';

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(pageTitle),
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh:
                  () => provider.fetchFinances(
                    token: context.read<AuthProvider>().token,
                  ),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Période d'analyse : pilote le bilan, les compteurs et la liste
                    _buildPeriodBar(provider.finances),
                    const SizedBox(height: 14),

                    // Top Green Banner matching "LIFE TIME SALE" from mockup
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(50),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'BILAN · ${_period.label.toUpperCase()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  border: Border.all(color: Colors.white),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  currency.format(balance, showSign: true),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            key: const ValueKey('period-description'),
                            _period.describe(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Recettes Ventes',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    // Les longs montants (ex. en FCFA) rétrécissent au lieu de déborder
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        currency.format(
                                          totalIncome,
                                          showSign: true,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Dépenses Clapier',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    // Les longs montants (ex. en FCFA) rétrécissent au lieu de déborder
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        currency.format(
                                          -totalExpense,
                                          showSign: true,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Quick Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap:
                                () => _showTransactionForm(
                                  context,
                                  provider,
                                  false,
                                ),
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            child: _buildActionTile(
                              icon: Icons.receipt_long,
                              title: 'Ajouter Dépense',
                              subtitle: 'Foin, granulés, vaccin',
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap:
                                () => _showTransactionForm(
                                  context,
                                  provider,
                                  true,
                                ),
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            child: _buildActionTile(
                              icon: Icons.add_shopping_cart,
                              title: 'Enregistrer Vente',
                              subtitle: 'Lapereaux, reproducteurs',
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // Filter chips (Tout, Dépenses, Ventes)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterTab(0, 'Toutes les transactions'),
                          const SizedBox(width: 8),
                          _buildFilterTab(
                            1,
                            'Dépenses (${totals.expenseCount})',
                          ),
                          const SizedBox(width: 8),
                          _buildFilterTab(2, 'Ventes (${totals.incomeCount})'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (filteredList.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: appCardDecoration(),
                        child: const Center(
                          child: Text(
                            'Aucune transaction sur cette période.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ...filteredList.map(
                        (fin) => _buildTransactionCard(
                          context,
                          provider,
                          fin,
                          currency,
                        ),
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterTab(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedFilterIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: appCardDecoration(shadow: true),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    RabbitProvider provider,
    FinanceTransaction fin,
    AppCurrency currency,
  ) {
    return InkWell(
      key: ValueKey('tx-${fin.id}'),
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap:
          () => _showTransactionForm(
            context,
            provider,
            fin.isIncome,
            existing: fin,
          ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: appCardDecoration(),
        child: Row(
          children: [
            BanknoteStackIcon(
              amount: fin.amount,
              isIncome: fin.isIncome,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fin.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${fin.category} • ${DateFormat('dd MMM yyyy', 'fr_FR').format(fin.date)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              currency.format(
                fin.isIncome ? fin.amount : -fin.amount,
                showSign: true,
              ),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color:
                    fin.isIncome
                        ? AppColors.statusActiveText
                        : Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Choix d'une période libre : tout l'historique, une année, ou une plage
/// de dates (du … au …). Renvoie la période choisie.
class _PeriodSheet extends StatefulWidget {
  const _PeriodSheet({required this.current, required this.firstYear});

  final FinancePeriod current;
  final int firstYear;

  @override
  State<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<_PeriodSheet> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final r = widget.current.range();
    _from = r?.start ?? DateTime(now.year, 1, 1);
    _to = r?.end ?? DateTime(now.year, now.month, now.day);
  }

  Future<void> _pick(bool from) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(widget.firstYear - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: from ? 'Date de début' : 'Date de fin',
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_from.isAfter(_to)) _from = _to;
      }
    });
  }

  Widget _option(String label, FinancePeriod period, {Key? key}) {
    final selected = widget.current == period;
    return ListTile(
      key: key,
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      trailing:
          selected
              ? const Icon(Icons.check_rounded, color: AppColors.primary)
              : null,
      onTap: () => Navigator.pop(context, period),
    );
  }

  Widget _dateField(String label, DateTime date, bool from) {
    return Expanded(
      child: InkWell(
        key: ValueKey(from ? 'period-from' : 'period-to'),
        onTap: () => _pick(from),
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.event_outlined, size: 20),
          ),
          child: Text(DateFormat('dd/MM/yyyy').format(date)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thisYear = DateTime.now().year;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choisir une période',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Plage de dates',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _dateField('Du', _from, true),
                  const SizedBox(width: 10),
                  _dateField('Au', _to, false),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  key: const ValueKey('period-apply'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: const StadiumBorder(),
                  ),
                  onPressed:
                      () => Navigator.pop(
                        context,
                        FinancePeriod.custom(
                          DateTimeRange(start: _from, end: _to),
                        ),
                      ),
                  child: const Text('Appliquer cette plage'),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Par année',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              for (var y = thisYear; y >= widget.firstYear; y--)
                _option(
                  y == thisYear
                      ? 'Cette année ($y)'
                      : (y == thisYear - 1
                          ? 'Année dernière ($y)'
                          : 'Année $y'),
                  FinancePeriod.year(y),
                  key: ValueKey('period-year-$y'),
                ),
              const Divider(),
              _option(
                "Tout l'historique",
                FinancePeriod.all,
                key: const ValueKey('period-all'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
