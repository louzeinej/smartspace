class Participation {
  final int? id;
  final int activiteId;
  final int utilisateurId;
  final String dateInscription;
  // Nombre de personnes inscrites avec cette participation (1 par défaut)
  final int nombrePersonnes;

  Participation({
    this.id,
    required this.activiteId,
    required this.utilisateurId,
    required this.dateInscription,
    this.nombrePersonnes = 1,
  });

  // Dart -> SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'activite_id': activiteId,
      'utilisateur_id': utilisateurId,
      'date_inscription': dateInscription,
      'nombre_personnes': nombrePersonnes,
    };
  }

  // SQLite -> Dart
  factory Participation.fromMap(Map<String, dynamic> map) {
    return Participation(
      id: map['id'] as int?,
      activiteId: map['activite_id'] as int,
      utilisateurId: map['utilisateur_id'] as int,
      dateInscription: map['date_inscription'] as String,
      nombrePersonnes: (map['nombre_personnes'] as int?) ?? 1,
    );
  }
}