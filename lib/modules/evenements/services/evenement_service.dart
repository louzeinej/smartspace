import '../entities/evenement.dart';
import 'database_service.dart';

class EvenementService {
  final DatabaseService _dbService = DatabaseService.instance;

  // CREATE : ajouter un événement
  Future<int> ajouter(Evenement evenement) async {
    final db = await _dbService.database;
    return await db.insert('evenements', evenement.toMap());
  }

  // READ : lire tous les événements, du plus proche au plus lointain
  Future<List<Evenement>> lireTous() async {
    final db = await _dbService.database;
    final lignes = await db.query('evenements', orderBy: 'date ASC');
    return lignes.map((ligne) => Evenement.fromMap(ligne)).toList();
  }

  // READ : lire UN événement par son id (null s'il n'existe pas)
  Future<Evenement?> lireParId(int id) async {
    final db = await _dbService.database;
    final lignes = await db.query(
      'evenements',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (lignes.isEmpty) return null;
    return Evenement.fromMap(lignes.first);
  }

  // UPDATE : modifier un événement
  Future<int> modifier(Evenement evenement) async {
    final db = await _dbService.database;
    return await db.update(
      'evenements',
      evenement.toMap(),
      where: 'id = ?',
      whereArgs: [evenement.id],
    );
  }

  // DELETE : supprimer un événement
  Future<int> supprimer(int id) async {
    final db = await _dbService.database;
    return await db.delete(
      'evenements',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}