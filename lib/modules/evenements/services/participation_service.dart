import '../entities/participation.dart';
import 'activite_service.dart';
import 'database_service.dart';

class ParticipationService {
  final DatabaseService _dbService = DatabaseService.instance;
  final ActiviteService _activiteService = ActiviteService();

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
  Future<int> nombrePersonnesInscrites(int activiteId, int utilisateurId) async {
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

    // On récupère la capacité, l'heure de fin et la date de l'événement
    final lignes = await db.rawQuery('''
      SELECT a.capacite_max, a.heure_fin, e.date
      FROM activites a
      JOIN evenements e ON e.id = a.evenement_id
      WHERE a.id = ?
    ''', [activiteId]);

    if (lignes.isEmpty) {
      throw Exception('Activité introuvable.');
    }

    final capaciteMax = lignes.first['capacite_max'] as int;
    final fin = DateTime.parse(
      '${lignes.first['date']} ${lignes.first['heure_fin']}',
    );

    // Règle 1 : pas d'inscription à une activité terminée
    if (fin.isBefore(DateTime.now())) {
      throw Exception('Cette activité est déjà terminée.');
    }

    // Règle 2 : pas de double inscription
    if (await estInscrit(activiteId, utilisateurId)) {
      throw Exception('Vous êtes déjà inscrit à cette activité.');
    }

    // Règle 3 : inscriptions closes si l'activité est complète
    final inscrits = await _activiteService.compterInscrits(activiteId);
    if (inscrits >= capaciteMax) {
      throw Exception('Activité complète : les inscriptions sont closes.');
    }

    // Règle 4 : pas plus de personnes que de places restantes
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

    // On récupère la capacité, l'heure de fin et la date de l'événement
    final lignes = await db.rawQuery('''
      SELECT a.capacite_max, a.heure_fin, e.date
      FROM activites a
      JOIN evenements e ON e.id = a.evenement_id
      WHERE a.id = ?
    ''', [activiteId]);

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