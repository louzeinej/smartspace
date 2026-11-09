import '../models/tache.dart';

/// Résultat d'une vérification de disponibilité.
class Disponibilite {
  /// Faux si la personne s'est déclarée indisponible.
  final bool personneDisponible;

  /// Première tâche qui chevauche la période demandée, s'il y en a une.
  final Tache? conflit;

  const Disponibilite({required this.personneDisponible, this.conflit});

  bool get estDisponible => personneDisponible && conflit == null;
}

/// Une personne est disponible sur [dateDebut]–[dateFin] (`yyyy-MM-dd`) si
/// [disponible] est vrai et si aucune de ses tâches non terminées ne
/// chevauche cette période, bornes incluses : une tâche qui finit le jour
/// où une autre commence est donc un conflit.
///
/// [tacheIgnoreeId] est la tâche en cours de traitement, qui ne doit pas
/// entrer en conflit avec elle-même.
Disponibilite verifierDisponibilite({
  required String dateDebut,
  required String dateFin,
  required Iterable<Tache> tachesDeLaPersonne,
  int? tacheIgnoreeId,
  bool disponible = true,
}) {
  if (!disponible) return const Disponibilite(personneDisponible: false);

  Tache? conflit;
  for (final t in tachesDeLaPersonne) {
    if (t.statut.estTerminee) continue;
    if (tacheIgnoreeId != null && t.id == tacheIgnoreeId) continue;
    final chevauche = t.dateDebut.compareTo(dateFin) <= 0 &&
        dateDebut.compareTo(t.dateFin) <= 0;
    if (!chevauche) continue;
    if (conflit == null || t.dateDebut.compareTo(conflit.dateDebut) < 0) {
      conflit = t;
    }
  }
  return Disponibilite(personneDisponible: true, conflit: conflit);
}
