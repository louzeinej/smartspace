import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../entities/evenement.dart';

class DatabaseService {
  // Une seule instance de cette classe dans toute l'application
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  // Donne la base de données (la crée si elle n'existe pas encore)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('smartspace_evenements.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 5,
      onConfigure: (db) async {
        // Active les liens entre les tables
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // Appelée une seule fois : crée les 3 tables
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE evenements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titre TEXT NOT NULL,
        description TEXT NOT NULL,
        date TEXT NOT NULL,
        lieu TEXT NOT NULL,
        image TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE activites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        evenement_id INTEGER NOT NULL,
        titre TEXT NOT NULL,
        description TEXT NOT NULL,
        heure_debut TEXT NOT NULL,
        heure_fin TEXT NOT NULL,
        capacite_max INTEGER NOT NULL,
        capacite_min INTEGER NOT NULL DEFAULT 0,
        categorie TEXT NOT NULL,
        FOREIGN KEY (evenement_id) REFERENCES evenements (id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE participations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activite_id INTEGER NOT NULL,
        utilisateur_id INTEGER NOT NULL,
        date_inscription TEXT NOT NULL,
        nombre_personnes INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (activite_id) REFERENCES activites (id)
          ON DELETE CASCADE,
        UNIQUE (activite_id, utilisateur_id)
      )
    ''');

    await _insererExemples(db);
    await _insererActivitesExemples(db);
  }

  // Passage de la version 1 à la version 2 : ajoute la colonne image
  // Passage à la version 3 : ajoute des activités d'exemple
  // Passage à la version 4 : ajoute nombre_personnes aux participations
  // Passage à la version 5 : ajoute capacite_min aux activités
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE evenements ADD COLUMN image TEXT');
      await _insererExemples(db);
    }
    if (oldVersion < 3) {
      await _insererActivitesExemples(db);
    }
    if (oldVersion < 4) {
      // Nombre de personnes par participation (les anciennes comptent pour 1)
      await db.execute(
        'ALTER TABLE participations ADD COLUMN nombre_personnes INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (oldVersion < 5) {
      // Minimum de participants (0 = pas de minimum)
      await db.execute(
        'ALTER TABLE activites ADD COLUMN capacite_min INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  // Cherche l'id d'un événement à partir de son titre (null si absent)
  Future<int?> _idEvenementParTitre(Database db, String titre) async {
    final lignes = await db.query(
      'evenements',
      columns: ['id'],
      where: 'titre = ?',
      whereArgs: [titre],
      limit: 1,
    );
    if (lignes.isEmpty) return null;
    return lignes.first['id'] as int;
  }

  // Ajoute des activités d'exemple, seulement si la table est vide
  Future<void> _insererActivitesExemples(Database db) async {
    final total = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM activites'),
    );
    if ((total ?? 0) > 0) return;

    final idSoiree = await _idEvenementParTitre(db, "Soirée de fin d'année");
    final idFormation = await _idEvenementParTitre(db, 'Journée de formation');
    final idTournoi =
        await _idEvenementParTitre(db, 'Tournoi sportif inter-équipes');

    // Soirée de fin d'année : 2 activités
    if (idSoiree != null) {
      await db.insert('activites', {
        'evenement_id': idSoiree,
        'titre': 'Concours de danse',
        'description': 'Venez montrer vos meilleurs pas de danse.',
        'heure_debut': '20:00',
        'heure_fin': '21:00',
        'capacite_max': 20,
        'categorie': 'Danse',
      });
      await db.insert('activites', {
        'evenement_id': idSoiree,
        'titre': 'Karaoké',
        'description': 'Chantez vos chansons préférées en équipe.',
        'heure_debut': '21:00',
        'heure_fin': '22:30',
        'capacite_max': 15,
        'categorie': 'Musique',
      });
    }

    // Journée de formation : 1 activité, déjà complète (2 inscrits sur 2)
    if (idFormation != null) {
      final idAtelier = await db.insert('activites', {
        'evenement_id': idFormation,
        'titre': 'Atelier Flutter',
        'description': 'Atelier pratique pour apprendre Flutter.',
        'heure_debut': '09:00',
        'heure_fin': '12:00',
        'capacite_max': 2,
        'categorie': 'Formation',
      });
      for (final utilisateurId in [2, 3]) {
        await db.insert('participations', {
          'activite_id': idAtelier,
          'utilisateur_id': utilisateurId,
          'date_inscription': DateTime.now().toIso8601String(),
        });
      }
    }

    // Tournoi sportif : 1 activité
    if (idTournoi != null) {
      await db.insert('activites', {
        'evenement_id': idTournoi,
        'titre': 'Match de padel',
        'description': 'Matchs amicaux de padel entre les équipes.',
        'heure_debut': '14:00',
        'heure_fin': '16:00',
        'capacite_max': 8,
        'categorie': 'Sport',
      });
    }
  }

  // Ajoute 3 événements d'exemple avec leur photo
  Future<void> _insererExemples(Database db) async {
    final exemples = [
      Evenement(
        titre: "Soirée de fin d'année",
        description: "Une soirée festive pour célébrer l'année avec toute l'équipe.",
        date: '2026-12-18',
        lieu: 'Terrasse du siège',
        image: 'fete.jpg',
      ),
      Evenement(
        titre: 'Journée de formation',
        description: "Présentation et ateliers pour développer les compétences de l'équipe.",
        date: '2026-11-20',
        lieu: 'Salle de formation',
        image: 'formation.jpg',
      ),
      Evenement(
        titre: 'Tournoi sportif inter-équipes',
        description: "Tournoi amical de pickleball entre les équipes de l'entreprise.",
        date: '2027-01-15',
        lieu: 'Complexe sportif',
        image: 'tournoi_sportif.jpg',
      ),
    ];
    for (final evenement in exemples) {
      await db.insert('evenements', evenement.toMap());
    }
  }
}
