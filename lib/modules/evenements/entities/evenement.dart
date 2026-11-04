class Evenement {
  final int? id;
  final String titre;
  final String description;
  final String date;
  final String lieu;
  final String? image;

  Evenement({
    this.id,
    required this.titre,
    required this.description,
    required this.date,
    required this.lieu,
    this.image,
  });

  // Dart -> SQLite : transforme l'événement en "ligne" de la table
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titre': titre,
      'description': description,
      'date': date,
      'lieu': lieu,
      'image': image,
    };
  }

  // SQLite -> Dart : transforme une "ligne" de la table en événement
  factory Evenement.fromMap(Map<String, dynamic> map) {
    return Evenement(
      id: map['id'] as int?,
      titre: map['titre'] as String,
      description: map['description'] as String,
      date: map['date'] as String,
      lieu: map['lieu'] as String,
      image: map['image'] as String?,
    );
  }
}