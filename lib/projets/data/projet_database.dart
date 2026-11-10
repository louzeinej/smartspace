import 'package:sqflite/sqflite.dart';

/// Tables du module Projets et Tâches.
///
/// La base elle-même est ouverte par `DatabaseHelper` (lib/core), qui appelle
/// [createTables] à la création puis la rejoue à chaque montée de version :
/// tout doit rester idempotent. Ces CREATE TABLE n'atteignent donc jamais un
/// appareil déjà migré : pour changer une colonne, ajouter un ALTER TABLE.
class ProjetDatabase {
  ProjetDatabase._();

  static Future<void> createTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS projets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titre TEXT NOT NULL,
        description TEXT NOT NULL,
        date_creation TEXT NOT NULL,
        createur_id INTEGER REFERENCES users(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS taches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titre TEXT NOT NULL,
        description TEXT NOT NULL,
        date_debut TEXT NOT NULL,
        date_fin TEXT NOT NULL,
        role_requis INTEGER NOT NULL,
        statut TEXT NOT NULL DEFAULT 'aFaire'
          CHECK (statut IN ('aFaire', 'enCours', 'terminee')),
        projet_id INTEGER NOT NULL REFERENCES projets(id) ON DELETE CASCADE,
        utilisateur_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
        CHECK (date_fin >= date_debut)
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_taches_projet ON taches(projet_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_taches_utilisateur ON taches(utilisateur_id)');
  }
}
