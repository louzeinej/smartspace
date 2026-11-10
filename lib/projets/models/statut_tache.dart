/// Statut d'une tâche (module Projets et Tâches).
///
/// Stocké en base par son nom ([name]), jamais sous forme de texte libre.
enum StatutTache {
  aFaire('À faire'),
  enCours('En cours'),
  terminee('Terminée');

  const StatutTache(this.label);

  /// Libellé affiché dans l'interface.
  final String label;

  /// Une tâche terminée ne bloque plus la disponibilité de la personne.
  bool get estTerminee => this == StatutTache.terminee;

  /// Conversion depuis le nom stocké en base. Une valeur inconnue lève une
  /// erreur : retomber sur « À faire » rendrait bloquante une tâche terminée.
  static StatutTache fromName(String name) => StatutTache.values.byName(name);
}
