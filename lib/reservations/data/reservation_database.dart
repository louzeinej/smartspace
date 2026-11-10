import 'package:sqflite/sqflite.dart';

/// Tables du module Réservations de Salles.
///
/// La base elle-même est ouverte par `DatabaseHelper` (lib/core), qui appelle
/// [createTables] à la création.
class ReservationDatabase {
  ReservationDatabase._();

  static Future<void> createTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS salles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero TEXT NOT NULL UNIQUE,
        emplacement TEXT NOT NULL,
        capacite INTEGER NOT NULL CHECK (capacite > 0)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reservations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        salle_id INTEGER NOT NULL REFERENCES salles(id) ON DELETE CASCADE,
        utilisateur_id INTEGER NOT NULL,
        objet TEXT NOT NULL,
        date TEXT NOT NULL,
        heure_debut TEXT NOT NULL,
        heure_fin TEXT NOT NULL,
        nb_personnes INTEGER NOT NULL CHECK (nb_personnes > 0)
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_resa_salle_date ON reservations(salle_id, date)');
    // Cache local des jours fériés reçus de l'API Nager.Date.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS jours_feries (
        date TEXT PRIMARY KEY,
        nom TEXT NOT NULL,
        annee INTEGER NOT NULL
      )
    ''');
  }

  /// Données de démonstration : si aucune salle n'existe, on en crée trois
  /// de tailles différentes pour pouvoir tester la réservation tout de suite.
  static Future<void> ajouterSallesDemoSiVide(Database db) async {
    final n = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM salles')) ?? 0;
    if (n > 0) return;
    final batch = db.batch();
    batch.insert('salles', {'numero': 'A1', 'emplacement': 'Bloc A, RDC', 'capacite': 4});
    batch.insert('salles', {'numero': 'B2', 'emplacement': 'Bloc B, 1er étage', 'capacite': 10});
    batch.insert('salles', {'numero': 'C3', 'emplacement': 'Bloc C, 2e étage', 'capacite': 30});
    await batch.commit(noResult: true);
  }
}
