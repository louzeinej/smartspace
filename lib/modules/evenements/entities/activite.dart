class Activite {
  final int? id;
  final int evenementId;
  final String titre;
  final String description;
  final String heureDebut;
  final String heureFin;
  final int capaciteMax;
  // Minimum de participants (0 = pas de minimum)
  final int capaciteMin;
  final String categorie;

  Activite({
    this.id,
    required this.evenementId,
    required this.titre,
    required this.description,
    required this.heureDebut,
    required this.heureFin,
    required this.capaciteMax,
    this.capaciteMin = 0,
    required this.categorie,
  });

  // Dart -> SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'evenement_id': evenementId,
      'titre': titre,
      'description': description,
      'heure_debut': heureDebut,
      'heure_fin': heureFin,
      'capacite_max': capaciteMax,
      'capacite_min': capaciteMin,
      'categorie': categorie,
    };
  }

  // SQLite -> Dart
  factory Activite.fromMap(Map<String, dynamic> map) {
    return Activite(
      id: map['id'] as int?,
      evenementId: map['evenement_id'] as int,
      titre: map['titre'] as String,
      description: map['description'] as String,
      heureDebut: map['heure_debut'] as String,
      heureFin: map['heure_fin'] as String,
      capaciteMax: map['capacite_max'] as int,
      capaciteMin: (map['capacite_min'] as int?) ?? 0,
      categorie: map['categorie'] as String,
    );
  }
}