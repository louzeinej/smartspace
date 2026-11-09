import 'package:sqflite/sqflite.dart';

import '../models/user_model.dart';
import '../core/database_helper.dart';

/// DAO (Data Access Object) : TOUT accès SQL à la table `users` passe
/// ici. Les écrans ne connaissent pas SQL — avantages :
///  1. requêtes centralisées et testables ;
///  2. requêtes PARAMÉTRÉES (`?`) partout → protection contre l'injection SQL ;
///  3. si un jour la table change, un seul fichier à modifier.
class UserDao {
  UserDao._();
  static final UserDao instance = UserDao._();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  // ── CREATE ────────────────────────────────────────────────────────
  /// Insère un utilisateur, retourne son id auto-généré.
  /// Lève `DatabaseException` (contrainte UNIQUE email) si l'email existe déjà.
  Future<int> insert(User user) async {
    final db = await _db;
    return db.insert('users', user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  // ── READ ──────────────────────────────────────────────────────────
  /// Liste tous les utilisateurs, triés par nom.
  Future<List<User>> getAll() async {
    final db = await _db;
    final rows = await db.query('users', orderBy: 'fullName COLLATE NOCASE');
    return rows.map(User.fromMap).toList();
  }

  /// Recherche par nom ou email (insensible à la casse), utilisée par
  /// la barre de recherche de l'écran Liste.
  Future<List<User>> search(String term) async {
    final db = await _db;
    final t = '%${term.trim().toLowerCase()}%';
    final rows = await db.query(
      'users',
      where: 'LOWER(fullName) LIKE ? OR LOWER(email) LIKE ?',
      whereArgs: [t, t],
      orderBy: 'fullName COLLATE NOCASE',
    );
    return rows.map(User.fromMap).toList();
  }

  /// Recherche un utilisateur par email (connexion).
  Future<User?> findByEmail(String email) async {
    final db = await _db;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  /// Recherche par numéro de téléphone (réinitialisation du mot de
  /// passe). La comparaison porte sur les chiffres uniquement, donc
  /// « 20 111 223 » et « 20111223 » correspondent.
  Future<User?> findByPhone(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) return null;
    final all = await getAll();
    for (final u in all) {
      if (u.phone.replaceAll(RegExp(r'\D'), '') == digits) return u;
    }
    return null;
  }

  /// Recherche par id (page de détail après navigation).
  Future<User?> findById(int id) async {
    final db = await _db;
    final rows =
        await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  /// Nombre total d'utilisateurs (amorçage du premier Administrateur).
  Future<int> countAll() async {
    final db = await _db;
    final res = await db.rawQuery('SELECT COUNT(*) AS n FROM users');
    return res.first['n'] as int;
  }

  /// Nombre d'utilisateurs par rôle (statistiques du tableau de bord).
  Future<Map<int, int>> countByRole() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT roleIndex, COUNT(*) AS n FROM users GROUP BY roleIndex',
    );
    return {
      for (final r in rows) r['roleIndex'] as int: r['n'] as int,
    };
  }

  // ── UPDATE ────────────────────────────────────────────────────────
  /// Met à jour un utilisateur, retourne 1 si succès, 0 sinon.
  Future<int> update(User user) async {
    final db = await _db;
    return db
        .update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  // ── DELETE ────────────────────────────────────────────────────────
  /// Supprime un utilisateur par id.
  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete('users', where: 'id = ?', whereArgs: [id]);
  }
}
