/// Projet créé par un utilisateur, décomposé ensuite en tâches.
class Projet {
  final int? id;
  final String titre;
  final String description;
  final String dateCreation; // yyyy-MM-dd

  /// Null si le compte du créateur a été supprimé (ON DELETE SET NULL).
  final int? createurId;

  const Projet({
    this.id,
    required this.titre,
    required this.description,
    required this.dateCreation,
    this.createurId,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'titre': titre,
        'description': description,
        'date_creation': dateCreation,
        'createur_id': createurId,
      };

  factory Projet.fromMap(Map<String, dynamic> m) => Projet(
        id: m['id'] as int?,
        titre: m['titre'] as String,
        description: m['description'] as String,
        dateCreation: m['date_creation'] as String,
        createurId: m['createur_id'] as int?,
      );
}
