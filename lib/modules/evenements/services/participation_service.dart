import '../entities/participation.dart';
import '../entities/regles_participation.dart';
import '../entities/statut_activite.dart';
import 'activite_service.dart';
import 'database_service.dart';

class ParticipationService {
  final DatabaseService _dbService = DatabaseService.instance;
  final ActiviteService _activiteService = ActiviteService();

  // Transforme "HH:MM" en nombre de minutes (ex : "10:30" -> 630)
  static int enMinutes(String heure) {
    final morceaux = heure.split(':');
    return int.parse(morceaux[0]) * 60 + int.parse(morceaux[1]);
  }

  // Deux créneaux se chevauchent si chacun commence avant la fin de l'autre.
  // Strict : 08:00-10:00 et 10:00-12:00 ne se chevauchent PAS.
  static bool chevauche(
    String debutA,
    String finA,
    String debutB,
    String finB,
  ) {
    return enMinutes(debutA) < enMinutes(finB) &&
        enMinutes(debutB) < enMinutes(finA);
  }

  // Est-ce que cet employé est déjà inscrit à cette activité ?
  Future<bool> estInscrit(int activiteId, int utilisateurId) async {
    final db = await _dbService.database;
    final lignes = await db.query(
      'participations',
      where: 'activite_id = ? AND utilisateur_id = ?',
      whereArgs: [activiteId, utilisateurId],
    );
    return lignes.isNotEmpty;
  }

  // Combien de personnes cet utilisateur a-t-il inscrites ? (0 si pas inscrit)
  Future<int> nombrePersonnesInscrites(
    int activiteId,
    int utilisateurId,
  ) async {
    final db = await _dbService.database;
    final lignes = await db.query(
      'participations',
      columns: ['nombre_personnes'],
      where: 'activite_id = ? AND utilisateur_id = ?',
      whereArgs: [activiteId, utilisateurId],
    );
    if (lignes.isEmpty) return 0;
    return (lignes.first['nombre_personnes'] as int?) ?? 1;
  }

  // Cherche une activité du même jour où l'employé participe déjà
  // et qui chevauche l'activité demandée.
  // Renvoie le titre de la première activité en conflit, ou null.
  Future<String?> trouverConflitHoraire(
    int activiteId,
    int utilisateurId,
  ) async {
    final db = await _dbService.database;

    // L'activité demandée, avec la date de son événement
    final cibles = await db.rawQuery(
      '''
      SELECT a.heure_debut, a.heure_fin, e.date
      FROM activites a
      JOIN evenements e ON e.id = a.evenement_id
      WHERE a.id = ?
    ''',
      [activiteId],
    );
    if (cibles.isEmpty) return null;

    final debut = cibles.first['heure_debut'] as String;
    final fin = cibles.first['heure_fin'] as String;
    final date = cibles.first['date'] as String;

    // Les autres activités de l'employé, le même jour (même événement ou non)
    final autres = await db.rawQuery(
      '''
      SELECT a.titre, a.heure_debut, a.heure_fin
      FROM participations p
      JOIN activites a ON a.id = p.activite_id
      JOIN evenements e ON e.id = a.evenement_id
      WHERE p.utilisateur_id = ? AND e.date = ? AND a.id <> ?
    ''',
      [utilisateurId, date, activiteId],
    );

    for (final autre in autres) {
      if (chevauche(
        debut,
        fin,
        autre['heure_debut'] as String,
        autre['heure_fin'] as String,
      )) {
        return autre['titre'] as String;
      }
    }
    return null;
  }

  // INSCRIRE : avec toutes les règles métier
  // nombrePersonnes = l'utilisateur + les personnes qui viennent avec lui
  Future<int> inscrire(
    int activiteId,
    int utilisateurId, {
    int nombrePersonnes = 1,
  }) async {
    final db = await _dbService.database;

    if (nombrePersonnes < 1) {
      throw Exception('Le nombre de personnes doit être au moins 1.');
    }

    // Pas plus de personnes que la limite par inscription
    if (nombrePersonnes > maxPersonnesParInscription) {
      throw Exception('Maximum $maxPersonnesParInscription personnes par inscription.');
    }

    // On récupère la capacité, l'heure de fin et la date de l'événement
    final lignes = await db.rawQuery(
      '''
      SELECT a.capacite_max, a.capacite_min, a.heure_debut, a.heure_fin, e.date
      FROM activites a
      JOIN evenements e ON e.id = a.evenement_id
      WHERE a.id = ?
    ''',
      [activiteId],
    );

    if (lignes.isEmpty) {
      throw Exception('Activité introuvable.');
    }

    final capaciteMax = lignes.first['capacite_max'] as int;
    final fin = DateTime.parse(
      '${lignes.first['date']} ${lignes.first['heure_fin']}',
    );

    // Statut de l'activité (avec le vrai nombre de personnes inscrites)
    final inscritsActuels = await _activiteService.compterInscrits(activiteId);
    final statut = calculerStatut(
      dateEvenement: lignes.first['date'] as String,
      heureDebut: lignes.first['heure_debut'] as String,
      heureFin: lignes.first['heure_fin'] as String,
      capaciteMax: capaciteMax,
      inscrits: inscritsActuels,
      capaciteMin: (lignes.first['capacite_min'] as int?) ?? 0,
    );

    // Règle 1 : pas d'inscription à une activité terminée
    if (fin.isBefore(DateTime.now())) {
      throw Exception('Cette activité est déjà terminée.');
    }

    // Règle 1 ter : activité annulée (minimum de participants non atteint)
    if (statut == StatutActivite.annulee) {
      throw Exception(
        "Activité annulée : le minimum de participants n'a pas été atteint.",
      );
    }

    // Règle 1 bis : pas d'inscription à une activité déjà commencée
    if (statut == StatutActivite.enCours) {
      throw Exception(
        "L'activité a déjà commencé : les inscriptions sont closes.",
      );
    }

    // Règle 2 : pas de double inscription
    if (await estInscrit(activiteId, utilisateurId)) {
      throw Exception('Vous êtes déjà inscrit à cette activité.');
    }

    // Règle 3 : pas deux activités qui se chevauchent le même jour
    final conflit = await trouverConflitHoraire(activiteId, utilisateurId);
    if (conflit != null) {
      throw Exception('Vous participez déjà à « $conflit » sur ce créneau.');
    }

    // Règle 4 : inscriptions closes si l'activité est complète
    final inscrits = await _activiteService.compterInscrits(activiteId);
    if (inscrits >= capaciteMax) {
      throw Exception('Activité complète : les inscriptions sont closes.');
    }

    // Règle 5 : pas plus de personnes que de places restantes
    final restantes = capaciteMax - inscrits;
    if (nombrePersonnes > restantes) {
      throw Exception('Il ne reste que $restantes place(s) disponible(s).');
    }

    // Tout est bon : on enregistre l'inscription
    final participation = Participation(
      activiteId: activiteId,
      utilisateurId: utilisateurId,
      dateInscription: DateTime.now().toIso8601String(),
      nombrePersonnes: nombrePersonnes,
    );
    return await db.insert('participations', participation.toMap());
  }

  // MODIFIER le nombre de personnes d'une participation existante
  Future<void> modifierNombrePersonnes(
    int activiteId,
    int utilisateurId,
    int nouveauNombre,
  ) async {
    final db = await _dbService.database;

    // La participation doit exister
    final actuel = await nombrePersonnesInscrites(activiteId, utilisateurId);
    if (actuel == 0) {
      throw Exception('Vous ne participez pas à cette activité.');
    }

    if (nouveauNombre < 1) {
      throw Exception('Le nombre de personnes doit être au moins 1.');
    }

    // Même limite, mais on laisse toujours réduire (ex : de 8 à 3)
    if (nouveauNombre > maxPersonnesParInscription && nouveauNombre > actuel) {
      throw Exception('Maximum $maxPersonnesParInscription personnes par inscription.');
    }

    // On récupère la capacité, l'heure de fin et la date de l'événement
    final lignes = await db.rawQuery(
      '''
      SELECT a.capacite_max, a.heure_fin, e.date
      FROM activites a
      JOIN evenements e ON e.id = a.evenement_id
      WHERE a.id = ?
    ''',
      [activiteId],
    );

    if (lignes.isEmpty) {
      throw Exception('Activité introuvable.');
    }

    final capaciteMax = lignes.first['capacite_max'] as int;
    final fin = DateTime.parse(
      '${lignes.first['date']} ${lignes.first['heure_fin']}',
    );

    // Pas de modification d'une activité terminée
    if (fin.isBefore(DateTime.now())) {
      throw Exception('Cette activité est déjà terminée.');
    }

    // Places libres pour ce groupe : on ne compte pas les personnes
    // de cet utilisateur, puisqu'elles vont être remplacées
    final inscrits = await _activiteService.compterInscrits(activiteId);
    final placesPourLeGroupe = capaciteMax - (inscrits - actuel);
    if (nouveauNombre > placesPourLeGroupe) {
      throw Exception(
        'Il ne reste que $placesPourLeGroupe place(s) disponible(s) pour votre groupe.',
      );
    }

    await db.update(
      'participations',
      {'nombre_personnes': nouveauNombre},
      where: 'activite_id = ? AND utilisateur_id = ?',
      whereArgs: [activiteId, utilisateurId],
    );
  }

  // DESINSCRIRE : annuler son inscription
  Future<int> desinscrire(int activiteId, int utilisateurId) async {
    final db = await _dbService.database;
    return await db.delete(
      'participations',
      where: 'activite_id = ? AND utilisateur_id = ?',
      whereArgs: [activiteId, utilisateurId],
    );
  }
}
