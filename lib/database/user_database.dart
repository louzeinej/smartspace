import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user_role.dart';

/// Questions secrètes proposées à l'inscription pour la réinitialisation
/// du mot de passe (application offline : pas d'envoi d'email possible,
/// on vérifie une information que l'utilisateur seul connaît).
const kSecurityQuestions = [
  'Quel est le nom de votre équipe ?',
  'Quel est le nom de votre première école ?',
  'Quel est votre plat préféré ?',
];

/// Script SQL du module Utilisateurs (Youssef Messoudi).
///
/// Suivant la convention du projet : chaque module expose une fonction
/// `createTables(db)` que `core/database_helper.dart` appelle dans son
/// `_onCreate` (et rejoue dans `_onUpgrade` grâce aux
/// CREATE TABLE IF NOT EXISTS).
class UserDatabase {
  UserDatabase._();

  /// Table `users` — mots de passe hachés SHA-256, email unique.
  static Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        fullName           TEXT    NOT NULL,
        email              TEXT    NOT NULL UNIQUE,
        passwordHash       TEXT    NOT NULL,
        roleIndex          INTEGER NOT NULL DEFAULT 5,
        avatarSeed         TEXT    NOT NULL,
        createdAt          INTEGER NOT NULL,
        securityQuestion   INTEGER NOT NULL DEFAULT -1,
        securityAnswerHash TEXT    NOT NULL DEFAULT '',
        phone              TEXT    NOT NULL DEFAULT ''
      )
    ''');
    // Migration : si la table existe déjà sans les colonnes de la
    // question secrète (v2 → v3), on les ajoute via ALTER TABLE.
    await _addColumnIfMissing(db, 'users', 'securityQuestion',
        'INTEGER NOT NULL DEFAULT -1');
    await _addColumnIfMissing(db, 'users', 'securityAnswerHash',
        "TEXT NOT NULL DEFAULT ''");
    await _addColumnIfMissing(db, 'users', 'phone',
        "TEXT NOT NULL DEFAULT ''");
    // Index sur l'email : la connexion fait un lookup par email.
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users (email)',
    );
  }

  static Future<void> _addColumnIfMissing(
      Database db, String table, String column, String definition) async {
    final cols = await db
        .rawQuery('PRAGMA table_info($table)');
    final exists = cols.any((c) => c['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  /// Comptes de démonstration (créés uniquement à la première
  /// installation — supprimer l'appel pour la version de production).
  static const demoCredentials = {
    'admin@smartspace.tn': 'Admin123',
    'scrum@smartspace.tn': 'Scrum123',
    'dev@smartspace.tn': 'Dev12345',
    'uiux@smartspace.tn': 'Uiux1234',
    'louzeine@smartspace.tn': 'Louz1234',
  };

  static Future<void> seedDemoUsers(Database db) async {
    String hash(String pwd) =>
        sha256.convert(pwd.codeUnits).toString();

    final demo = [
      // [nom, email, mot de passe, rôle, graine avatar, téléphone]
      // Rôles alignés sur l'organisation de l'équipe (cahier des
      // charges §4) : Messoudi gère comptes/rôles -> Administrateur.
      ['Youssef Messoudi', 'dev@smartspace.tn', 'Dev12345',
          UserRole.administrateur.index, 'youssef-dev', '20111223'],
      ['Youssef Sghaier', 'scrum@smartspace.tn', 'Scrum123',
          UserRole.scrumMaster.index, 'youssef-scrum', '20333445'],
      ['Youssef Fadaoui', 'admin@smartspace.tn', 'Admin123',
          UserRole.administrateur.index, 'youssef-admin', '20555667'],
      ['Manar Kalai', 'uiux@smartspace.tn', 'Uiux1234',
          UserRole.uiuxDesigner.index, 'manar-uiux', '98776655'],
      ['Louzeine Aloui', 'louzeine@smartspace.tn', 'Louz1234',
          UserRole.rh.index, 'louzeine-rh', '94445533'],
    ];

    final count =
        await db.rawQuery('SELECT COUNT(*) AS n FROM users');
    if ((count.first['n'] as int) > 0) return; // déjà seedé

    final batch = db.batch();
    for (final row in demo) {
      batch.insert('users', {
        'fullName': row[0],
        'email': row[1],
        'passwordHash': hash(row[2] as String),
        'roleIndex': row[3] as int,
        'avatarSeed': row[4] as String,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        // Question secrète de démo : « Quel est le nom de votre équipe ? »
        // Réponse : smartspace
        'securityQuestion': 0,
        'securityAnswerHash': hash('smartspace'),
        'phone': row[5] as String,
      });
    }
    await batch.commit(noResult: true);
  }
}
