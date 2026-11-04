import 'package:sqflite/sqflite.dart';
import '../entities/activite.dart';
import 'database_service.dart';

class ActiviteService {
  final DatabaseService _dbService = DatabaseService.instance;

  // CREATE : ajouter une activité
  Future<int> ajouter(Activite activite) async {
    final db = await _dbService.database;
    return await db.insert('activites', activite.toMap());
  }

  // READ : lire les activités d'UN événement, par heure de début
  Future<List<Activite>> lireParEvenement(int evenementId) async {
    final db = await _dbService.database;
    final lignes = await db.query(
      'activites',
      where: 'evenement_id = ?',
      whereArgs: [evenementId],
      orderBy: 'heure_debut ASC',
    );
    return lignes.map((ligne) => Activite.fromMap(ligne)).toList();
  }

  // Compter combien de PERSONNES sont inscrites à une activité
  // (on additionne le nombre de personnes de chaque participation)
  Future<int> compterInscrits(int activiteId) async {
    final db = await _dbService.database;
    final resultat = await db.rawQuery(
      'SELECT COALESCE(SUM(nombre_personnes), 0) FROM participations WHERE activite_id = ?',
      [activiteId],
    );
    return Sqflite.firstIntValue(resultat) ?? 0;
  }

  // UPDATE : modifier une activité
  // Règle : on ne peut pas mettre une capacité plus petite
  // que le nombre d'inscrits actuel
  Future<int> modifier(Activite activite) async {
    final inscrits = await compterInscrits(activite.id!);
    if (activite.capaciteMax < inscrits) {
      throw Exception(
        'La capacité ne peut pas être inférieure au nombre d\'inscrits ($inscrits).',
      );
    }
    final db = await _dbService.database;
    return await db.update(
      'activites',
      activite.toMap(),
      where: 'id = ?',
      whereArgs: [activite.id],
    );
  }

  // DELETE : supprimer une activité
  Future<int> supprimer(int id) async {
    final db = await _dbService.database;
    return await db.delete(
      'activites',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}