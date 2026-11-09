import '../../models/user_role.dart';
import 'statut_tache.dart';

/// Tâche d'un projet, affectée à un utilisateur ayant le rôle requis.
///
/// Les dates sont stockées en texte `yyyy-MM-dd` : ce format se compare
/// correctement comme du texte, en Dart comme dans SQLite.
class Tache {
  final int? id;
  final String titre;
  final String description;
  final String dateDebut; // yyyy-MM-dd
  final String dateFin; // yyyy-MM-dd
  final UserRole roleRequis;
  final StatutTache statut;
  final int projetId;

  /// Null tant que la tâche n'est pas affectée, ou si le compte de la
  /// personne a été supprimé (ON DELETE SET NULL).
  final int? utilisateurId;

  // Rempli uniquement lors des lectures avec jointure (affichage).
  final String? projetTitre;

  const Tache({
    this.id,
    required this.titre,
    required this.description,
    required this.dateDebut,
    required this.dateFin,
    required this.roleRequis,
    this.statut = StatutTache.aFaire,
    required this.projetId,
    this.utilisateurId,
    this.projetTitre,
  });

  bool get estAffectee => utilisateurId != null;

  // utilisateur_id reste présent même à null : sinon une mise à jour
  // ne pourrait jamais retirer une affectation.
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'titre': titre,
        'description': description,
        'date_debut': dateDebut,
        'date_fin': dateFin,
        'role_requis': roleRequis.index,
        'statut': statut.name,
        'projet_id': projetId,
        'utilisateur_id': utilisateurId,
      };

  factory Tache.fromMap(Map<String, dynamic> m) => Tache(
        id: m['id'] as int?,
        titre: m['titre'] as String,
        description: m['description'] as String,
        dateDebut: m['date_debut'] as String,
        dateFin: m['date_fin'] as String,
        roleRequis: UserRole.fromIndex(m['role_requis'] as int),
        statut: StatutTache.fromName(m['statut'] as String),
        projetId: m['projet_id'] as int,
        utilisateurId: m['utilisateur_id'] as int?,
        projetTitre: m['projet_titre'] as String?,
      );
}
