import 'package:sqflite/sqflite.dart';

import '../../core/database_helper.dart';
import '../../database/user_dao.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../models/projet.dart';
import '../models/statut_tache.dart';
import '../models/tache.dart';

class ProjetException implements Exception {
  final String message;
  ProjetException(this.message);
  @override
  String toString() => message;
}

/// CRUD des projets et des tâches, et affectation d'une tâche.
class ProjetService {
  ProjetService({
    Future<Database>? database,
    Future<List<User>> Function()? lireUtilisateurs,
  })  : _database = database ?? DatabaseHelper.instance.database,
        _lireUtilisateurs = lireUtilisateurs ?? UserDao.instance.getAll;

  final Future<Database> _database;
  final Future<List<User>> Function() _lireUtilisateurs;

  // --------------------------------------------------------------- Projets

  Future<List<Projet>> getProjets() async {
    final db = await _database;
    final rows =
        await db.query('projets', orderBy: 'date_creation DESC, id DESC');
    return rows.map(Projet.fromMap).toList();
  }

  Future<int> creerProjet(Projet projet) async {
    final db = await _database;
    return db.insert('projets', projet.toMap());
  }

  /// La date de création et le créateur ne changent jamais.
  Future<void> modifierProjet(Projet projet) async {
    final db = await _database;
    await db.update(
      'projets',
      {'titre': projet.titre, 'description': projet.description},
      where: 'id = ?',
      whereArgs: [projet.id],
    );
  }

  /// Supprime le projet et ses tâches (ON DELETE CASCADE).
  Future<void> supprimerProjet(int id) async {
    final db = await _database;
    await db.delete('projets', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------- Tâches

  Future<List<Tache>> getTachesProjet(int projetId) async {
    final db = await _database;
    final rows = await db.query('taches',
        where: 'projet_id = ?',
        whereArgs: [projetId],
        orderBy: 'date_debut, id');
    return rows.map(Tache.fromMap).toList();
  }

  /// Tâches affectées à [utilisateurId], avec le titre de leur projet.
  Future<List<Tache>> getTachesUtilisateur(int utilisateurId) async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT t.*, p.titre AS projet_titre
      FROM taches t JOIN projets p ON p.id = t.projet_id
      WHERE t.utilisateur_id = ?
      ORDER BY t.date_debut, t.id
    ''', [utilisateurId]);
    return rows.map(Tache.fromMap).toList();
  }

  /// Une nouvelle tâche n'est jamais affectée : seul [affecterA] le permet.
  Future<int> creerTache(Tache tache) async {
    _verifierPeriode(tache.dateDebut, tache.dateFin);
    final db = await _database;
    return db.insert('taches', {...tache.toMap(), 'utilisateur_id': null});
  }

  /// N'écrit que les champs du formulaire : le statut et l'affectation
  /// ne changent que par [changerStatut] et [affecterA].
  Future<void> modifierTache(Tache tache) async {
    _verifierPeriode(tache.dateDebut, tache.dateFin);
    final db = await _database;
    await db.update(
      'taches',
      {
        'titre': tache.titre,
        'description': tache.description,
        'date_debut': tache.dateDebut,
        'date_fin': tache.dateFin,
        'role_requis': tache.roleRequis.index,
      },
      where: 'id = ?',
      whereArgs: [tache.id],
    );
  }

  Future<void> changerStatut(int tacheId, StatutTache statut) async {
    final db = await _database;
    await db.update('taches', {'statut': statut.name},
        where: 'id = ?', whereArgs: [tacheId]);
  }

  Future<void> supprimerTache(int id) async {
    final db = await _database;
    await db.delete('taches', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------ Affectation

  /// Utilisateurs ayant exactement le rôle demandé.
  Future<List<User>> getCandidats(UserRole role) async {
    final utilisateurs = await _lireUtilisateurs();
    return utilisateurs.where((u) => u.role == role).toList();
  }

  /// Relit la tâche dans la transaction : l'écran peut afficher des
  /// données périmées au moment où l'affectation est confirmée.
  Future<void> affecterA(Tache tache, User utilisateur) async {
    final db = await _database;
    await db.transaction((txn) async {
      final actuelle = await _lireTache(txn, tache.id!);
      if (actuelle.statut.estTerminee) {
        throw ProjetException('Une tâche terminée ne peut pas être affectée.');
      }
      if (utilisateur.role != actuelle.roleRequis) {
        throw ProjetException(
            'Cette tâche demande le rôle ${actuelle.roleRequis.label}.');
      }
      await txn.update('taches', {'utilisateur_id': utilisateur.id},
          where: 'id = ?', whereArgs: [actuelle.id]);
    });
  }

  // ---------------------------------------------------------------- Interne

  Future<Tache> _lireTache(DatabaseExecutor ex, int id) async {
    final rows =
        await ex.query('taches', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw ProjetException('Cette tâche n\'existe plus.');
    return Tache.fromMap(rows.first);
  }

  void _verifierPeriode(String debut, String fin) {
    if (fin.compareTo(debut) < 0) {
      throw ProjetException(
          'La date de fin ne peut pas précéder la date de début.');
    }
  }
}
