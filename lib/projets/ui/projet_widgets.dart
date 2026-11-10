import 'package:flutter/material.dart';

import '../../reservations/ui/smartspace_style.dart';
import '../models/statut_tache.dart';
import '../services/projet_service.dart';

/// En-tête violet de la charte. Le titre est stylé explicitement : le thème
/// global impose sinon un titre sombre, peu lisible sur le violet.
AppBar projetAppBar(
  String titre, {
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) =>
    AppBar(
      backgroundColor: SsColors.primaire,
      foregroundColor: Colors.white,
      titleTextStyle: SsText.titreEcran.copyWith(color: Colors.white),
      title: Text(titre),
      actions: actions,
      bottom: bottom,
    );

/// Badge pilule du statut d'une tâche.
class StatutBadge extends StatelessWidget {
  const StatutBadge({super.key, required this.statut});
  final StatutTache statut;

  @override
  Widget build(BuildContext context) => SsBadge(
        label: statut.label,
        couleur: switch (statut) {
          StatutTache.aFaire => SsColors.secondaire,
          StatutTache.enCours => SsColors.primaire,
          StatutTache.terminee => SsColors.succes,
        },
      );
}

/// Message centré affiché quand une liste est vide.
class EtatVide extends StatelessWidget {
  const EtatVide({super.key, required this.icone, required this.message});
  final IconData icone;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 48, color: SsColors.primaire),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: SsText.courant),
        ],
      ),
    );
  }
}

/// yyyy-MM-dd, yyyy-MM-dd -> « Du 01/03/2026 au 05/03/2026 ».
String afficherPeriode(String debut, String fin) => debut == fin
    ? 'Le ${afficherDate(debut)}'
    : 'Du ${afficherDate(debut)} au ${afficherDate(fin)}';

Future<bool> confirmerSuppression(
  BuildContext context, {
  required String titre,
  required String message,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titre),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Supprimer',
              style: TextStyle(color: SsColors.alerte)),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Explique pourquoi l'enregistrement est refusé. Renvoie vrai seulement si
/// l'utilisateur choisit explicitement de retirer l'affectation.
Future<bool> proposerRetraitAffectation(
    BuildContext context, ConflitAffectationException erreur) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Enregistrement impossible'),
      content: Text(erreur.message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Retirer l\'affectation et enregistrer',
              style: TextStyle(color: SsColors.alerte)),
        ),
      ],
    ),
  );
  return ok == true;
}
