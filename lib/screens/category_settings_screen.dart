import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/finance_transaction.dart';
import '../providers/category_provider.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';

/// Gestion des catégories de dépenses et de revenus utilisées dans le formulaire
/// de transaction (module Finances).
class CategorySettingsScreen extends StatelessWidget {
  const CategorySettingsScreen({super.key});

  Future<void> _addCategory(BuildContext context, TransactionType type) async {
    final controller = TextEditingController();
    final categories = context.read<CategoryProvider>();
    final added = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              type == TransactionType.income
                  ? 'Nouvelle catégorie de revenu'
                  : 'Nouvelle catégorie de dépense',
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Ex: Location de matériel'),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Ajouter'),
              ),
            ],
          ),
    );
    if (added == true && controller.text.trim().isNotEmpty) {
      await categories.addCategory(type, controller.text.trim());
    }
  }

  Future<void> _confirmRemove(
    BuildContext context,
    TransactionType type,
    String label,
  ) async {
    final categories = context.read<CategoryProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Supprimer cette catégorie ?'),
            content: Text(
              '« $label » ne sera plus proposée dans le formulaire. Les transactions '
              'déjà enregistrées avec cette catégorie ne sont pas modifiées.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await categories.removeCategory(type, label);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        title: const Text(
          'Catégories',
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
              "Utilisées dans le formulaire d'ajout de vente ou de dépense (module Finances).",
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            _categorySection(
              context,
              title: 'Revenus',
              type: TransactionType.income,
              items: categories.incomeCategories,
            ),
            const SizedBox(height: 20),
            _categorySection(
              context,
              title: 'Dépenses',
              type: TransactionType.expense,
              items: categories.expenseCategories,
            ),
          ],
        ),
      ),
    );
  }

  Widget _categorySection(
    BuildContext context, {
    required String title,
    required TransactionType type,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                ListTile(
                  key: ValueKey('category-${type.name}-${items[i]}'),
                  dense: true,
                  title: Text(items[i]),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => _confirmRemove(context, type, items[i]),
                  ),
                ),
                const Divider(height: 1, indent: 16, color: Color(0xFFEDEFED)),
              ],
              ListTile(
                key: ValueKey('add-category-${type.name}'),
                dense: true,
                leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                title: const Text(
                  'Ajouter une catégorie',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
                onTap: () => _addCategory(context, type),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
