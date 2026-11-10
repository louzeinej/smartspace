import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../database/user_database.dart';
import '../networking/data/networking_database.dart';
import '../projets/data/projet_database.dart';
import '../reservations/data/reservation_database.dart';

/// Base SQLite unique de SmartSpace, partagée par les 5 modules.
///
/// Chaque module fournit sa fonction `createTables(db)` et l'ajoute
/// dans [_onCreate]. Augmenter [_version] et compléter [_onUpgrade]
/// quand un module ajoute des tables après une première installation.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _nom = 'smartspace.db';
  // v4 : téléphone (Utilisateurs) · v5 : jours_feries + projets/taches
  //     + networking (fusions parallèles des modules)
  // v6 : rattrapage — la v5 a été attribuée en parallèle par trois modules,
  //      un appareil déjà en v5 n'avait donc qu'une partie de leurs tables.
  static const _version = 6;

  Database? _db;

  Future<Database> get database async {
    _db ??= await openDatabase(
      join(await getDatabasesPath(), _nom),
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) => _onCreate(db),
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await ReservationDatabase.ajouterSallesDemoSiVide(db);
        await NetworkingDatabase.seedDemoPublicationsIfEmpty(db);
      },
    );
    return _db!;
  }

  Future<void> _onCreate(Database db) async {
    // Module Utilisateurs (Youssef Messoudi)
    await UserDatabase.createTables(db);
    await UserDatabase.seedDemoUsers(db);
    await ProjetDatabase.createTables(db); // Module Projets et Tâches (Youssef Sghaier)
    await ReservationDatabase.createTables(db); // Module Réservations (Youssef Fadaoui)
    await NetworkingDatabase.createTables(db);  // Module Networking (Manar Kalai)
    // Module Événements et Club (Louzeine Aloui)  : à ajouter
  }

  Future<void> _onUpgrade(Database db, int ancienne, int nouvelle) async {
    // Les CREATE TABLE IF NOT EXISTS permettent de rejouer la création sans risque.
    await _onCreate(db);
  }
}
