import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user_role.dart';

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
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        fullName      TEXT    NOT NULL,
        email         TEXT    NOT NULL UNIQUE,
        passwordHash  TEXT    NOT NULL,
        roleIndex     INTEGER NOT NULL DEFAULT 5,
        avatarSeed    TEXT    NOT NULL,
        createdAt     INTEGER NOT NULL
      )
    ''');
    // Index sur l'email : la connexion fait un lookup par email.
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users (email)',
    );
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
      // [nom, email, mot de passe, rôle, graine avatar]
      ['Youssef Messoudi', 'dev@smartspace.tn', 'Dev12345',
          UserRole.developpeur.index, 'youssef-dev'],
      ['Youssef Sghaier', 'scrum@smartspace.tn', 'Scrum123',
          UserRole.scrumMaster.index, 'youssef-scrum'],
      ['Youssef Fadaoui', 'admin@smartspace.tn', 'Admin123',
          UserRole.administrateur.index, 'youssef-admin'],
      ['Manar Kalai', 'uiux@smartspace.tn', 'Uiux1234',
          UserRole.uiuxDesigner.index, 'manar-uiux'],
      ['Louzeine Aloui', 'louzeine@smartspace.tn', 'Louz1234',
          UserRole.rh.index, 'louzeine-rh'],
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
      });
    }
    await batch.commit(noResult: true);
  }
}
