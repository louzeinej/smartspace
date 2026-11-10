import 'package:flutter/material.dart';

// Statut d'une activité : calculé automatiquement, jamais saisi
enum StatutActivite {
  ouverte,
  presqueComplete,
  complete,
  enCours,
  terminee,
  annulee,
}

// Calcule le statut. Le premier cas vrai gagne :
// annulée, terminée, en cours, complète, presque complète, sinon ouverte.
StatutActivite calculerStatut({
  required String dateEvenement,
  required String heureDebut,
  required String heureFin,
  required int capaciteMax,
  required int inscrits,
  int capaciteMin = 0,
  DateTime? maintenant,
}) {
  final now = maintenant ?? DateTime.now();
  final debut = DateTime.parse('$dateEvenement $heureDebut');
  final fin = DateTime.parse('$dateEvenement $heureFin');

  // a) Annulée : l'activité a commencé sans atteindre le minimum de participants
  if (capaciteMin > 0 && !now.isBefore(debut) && inscrits < capaciteMin) {
    return StatutActivite.annulee;
  }
  // b) L'heure de fin est passée
  if (!now.isBefore(fin)) return StatutActivite.terminee;
  // c) L'heure de début est passée (même si l'activité est pleine)
  if (!now.isBefore(debut)) return StatutActivite.enCours;
  // d) Plus aucune place
  if (inscrits >= capaciteMax) return StatutActivite.complete;
  // e) Au moins 80 % des places prises
  if (inscrits * 100 >= capaciteMax * 80) return StatutActivite.presqueComplete;
  // f) Sinon, il reste de la place
  return StatutActivite.ouverte;
}

// Pourcentage de places prises (entier entre 0 et 100)
int pourcentageOccupation(int inscrits, int capaciteMax) {
  if (capaciteMax <= 0) return 0;
  final pourcentage = (inscrits * 100 / capaciteMax).round();
  return pourcentage > 100 ? 100 : pourcentage;
}

// Texte et couleur affichés pour chaque statut
extension StatutActiviteAffichage on StatutActivite {
  String get libelle {
    switch (this) {
      case StatutActivite.ouverte:
        return 'Ouverte';
      case StatutActivite.presqueComplete:
        return 'Presque complète';
      case StatutActivite.complete:
        return 'Complète';
      case StatutActivite.enCours:
        return 'En cours';
      case StatutActivite.terminee:
        return 'Terminée';
      case StatutActivite.annulee:
        return 'Annulée';
    }
  }

  Color get couleur {
    switch (this) {
      case StatutActivite.ouverte:
        return const Color(0xFF2ECC71);
      case StatutActivite.presqueComplete:
        return const Color(0xFFF5A623);
      case StatutActivite.complete:
        return const Color(0xFFFF6B6B);
      case StatutActivite.enCours:
        return const Color(0xFF2D2A4A);
      case StatutActivite.terminee:
        return const Color(0xFF9E9E9E);
      case StatutActivite.annulee:
        return const Color(0xFFC0392B);
    }
  }
}
