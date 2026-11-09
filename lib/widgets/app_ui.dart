import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radius.dart';

/// Message éphémère en bas d'écran : vert de l'app, ou rouge pour une erreur.
/// Remplace le message précédent s'il est encore affiché.
void showAppSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : AppColors.primary,
      ),
    );
}

/// Boîte de confirmation « Annuler / action » : true si l'utilisateur confirme.
/// [destructive] met le bouton d'action en rouge (suppression, déconnexion…).
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Supprimer',
  String cancelLabel = 'Annuler',
  bool destructive = false,
  Key? confirmKey,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              key: confirmKey,
              style: FilledButton.styleFrom(
                backgroundColor:
                    destructive ? Colors.red.shade700 : AppColors.primary,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
  );
  return ok == true;
}

/// Contenu standard d'une feuille modale de formulaire : marges, défilement et
/// remontée au-dessus du clavier.
class SheetBody extends StatelessWidget {
  final List<Widget> children;

  const SheetBody({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

/// Bouton principal pleine largeur d'un formulaire ; affiche un indicateur et se
/// désactive pendant l'enregistrement ([saving]).
class SubmitButton extends StatelessWidget {
  final String label;
  final bool saving;
  final VoidCallback onPressed;

  const SubmitButton({
    super.key,
    required this.label,
    required this.saving,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: saving ? null : onPressed,
        child:
            saving
                ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                : Text(label),
      ),
    );
  }
}

/// Fond des cartes de l'app : blanc, coins arrondis, fin liseré (avec ombre légère si [shadow]).
BoxDecoration appCardDecoration({bool shadow = false}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(AppRadius.card),
  border: Border.all(color: AppColors.cardBorder),
  boxShadow:
      shadow
          ? [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
          : null,
);
