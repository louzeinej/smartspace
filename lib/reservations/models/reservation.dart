/// Réservation d'une salle sur un créneau.
///
/// Les dates sont stockées en texte `yyyy-MM-dd` et les heures en `HH:mm` :
/// ce format se compare correctement comme du texte dans SQLite.
class Reservation {
  final int? id;
  final int salleId;
  final int utilisateurId;
  final String objet;
  final String date; // yyyy-MM-dd
  final String heureDebut; // HH:mm
  final String heureFin; // HH:mm
  final int nbPersonnes;

  // Rempli uniquement lors des lectures avec jointure (affichage).
  final String? salleNumero;
  final String? salleEmplacement;

  const Reservation({
    this.id,
    required this.salleId,
    required this.utilisateurId,
    required this.objet,
    required this.date,
    required this.heureDebut,
    required this.heureFin,
    required this.nbPersonnes,
    this.salleNumero,
    this.salleEmplacement,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'salle_id': salleId,
        'utilisateur_id': utilisateurId,
        'objet': objet,
        'date': date,
        'heure_debut': heureDebut,
        'heure_fin': heureFin,
        'nb_personnes': nbPersonnes,
      };

  factory Reservation.fromMap(Map<String, dynamic> m) => Reservation(
        id: m['id'] as int?,
        salleId: m['salle_id'] as int,
        utilisateurId: m['utilisateur_id'] as int,
        objet: m['objet'] as String,
        date: m['date'] as String,
        heureDebut: m['heure_debut'] as String,
        heureFin: m['heure_fin'] as String,
        nbPersonnes: m['nb_personnes'] as int,
        salleNumero: m['salle_numero'] as String?,
        salleEmplacement: m['salle_emplacement'] as String?,
      );
}
