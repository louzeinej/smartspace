/// Salle référencée par un administrateur.
class Salle {
  final int? id;
  final String numero;
  final String emplacement;
  final int capacite;

  const Salle({
    this.id,
    required this.numero,
    required this.emplacement,
    required this.capacite,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'numero': numero,
        'emplacement': emplacement,
        'capacite': capacite,
      };

  factory Salle.fromMap(Map<String, dynamic> m) => Salle(
        id: m['id'] as int?,
        numero: m['numero'] as String,
        emplacement: m['emplacement'] as String,
        capacite: m['capacite'] as int,
      );

  Salle copyWith({int? id, String? numero, String? emplacement, int? capacite}) =>
      Salle(
        id: id ?? this.id,
        numero: numero ?? this.numero,
        emplacement: emplacement ?? this.emplacement,
        capacite: capacite ?? this.capacite,
      );
}
