import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../database/user_dao.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import 'avatar_service.dart';

/// Cœur MÉTIER du module : inscription, connexion, session.
///
/// Sécurité : les mots de passe ne sont jamais stockés ni comparés en
/// clair — on hache avec SHA-256 (`crypto`) puis on compare les
/// empreintes. (Argument clé pour la session Q/A : même si quelqu'un
/// lit la base SQLite, il ne voit pas les mots de passe.)
///
/// Session : l'id de l'utilisateur connecté est persisté dans
/// SharedPreferences pour survivre au redémarrage de l'application.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _sessionKey = 'smartspace_session_user_id';

  final UserDao _dao = UserDao.instance;

  /// Utilisateur actuellement connecté (null si déconnecté).
  User? currentUser;

  /// Résultat d'une opération d'authentification, avec un message
  /// métier exploitable directement par l'UI.
  AuthResult success(User user) => AuthResult._(ok: true, user: user);
  AuthResult failure(String message) => AuthResult._(ok: false, message: message);

  // ── INSCRIPTION ───────────────────────────────────────────────────
  /// Règles métier appliquées (au-delà de la validation de formulaire) :
  ///  - email unique en base (contrainte SQLite + vérification anticipée) ;
  ///  - mot de passe haché avant tout stockage ;
  ///  - graine d'avatar générée pour le web service DiceBear.
  Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    // Vérification anticipée de l'unicité (la contrainte UNIQUE en base
    // reste le garde-fou final).
    final existing = await _dao.findByEmail(normalizedEmail);
    if (existing != null) {
      return failure('Un compte existe déjà avec cet email.');
    }

    // Règle d'accès métier : le PREMIER compte créé devient
    // Administrateur (amorçage du système). Ensuite, personne ne peut
    // s'auto-attribuer le rôle Administrateur à l'inscription — seule
    // une promotion par un Administrateur existant est possible
    // (voir EditUserScreen).
    final userCount = await _dao.countAll();
    final effectiveRole =
        userCount == 0 ? UserRole.administrateur : role;

    final user = User(
      fullName: fullName.trim(),
      email: normalizedEmail,
      passwordHash: _hash(password),
      role: effectiveRole,
      avatarSeed: AvatarService.randomSeed(),
      createdAt: DateTime.now(),
    );

    try {
      final id = await _dao.insert(user);
      return success(User(
        id: id,
        fullName: user.fullName,
        email: user.email,
        passwordHash: user.passwordHash,
        role: user.role,
        avatarSeed: user.avatarSeed,
        createdAt: user.createdAt,
      ));
    } on DatabaseException catch (e) {
      // 2067 = SQLITE_CONSTRAINT (email dupliqué malgré le check)
      if (e.isUniqueConstraintError()) {
        return failure('Un compte existe déjà avec cet email.');
      }
      return failure('Erreur base de données : ${e.getResultCode()}');
    }
  }

  // ── CONNEXION ─────────────────────────────────────────────────────
  Future<AuthResult> login(String email, String password) async {
    final user = await _dao.findByEmail(email);
    if (user == null) {
      // Message volontairement générique : ne pas révéler si l'email
      // existe (bonne pratique de sécurité à citer en soutenance).
      return failure('Email ou mot de passe incorrect.');
    }
    if (user.passwordHash != _hash(password)) {
      return failure('Email ou mot de passe incorrect.');
    }
    currentUser = user;
    await _persistSession(user.id!);
    return success(user);
  }

  // ── DÉCONNEXION ───────────────────────────────────────────────────
  Future<void> logout() async {
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  // ── SESSION ───────────────────────────────────────────────────────
  /// Au démarrage : restaure la session persisted (splash screen).
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_sessionKey);
    if (id == null) return;
    currentUser = await _dao.findById(id);
    // Compte supprimé entre-temps → nettoyer la session orpheline.
    if (currentUser == null) await prefs.remove(_sessionKey);
  }

  Future<void> _persistSession(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sessionKey, userId);
  }

  /// Relit un utilisateur depuis la base (après édition de profil).
  Future<User?> restoreById(int userId) => _dao.findById(userId);

  /// Changement de mot de passe (avec vérification de l'ancien).
  Future<AuthResult> changePassword(
      User user, String oldPassword, String newPassword) async {
    if (user.passwordHash != _hash(oldPassword)) {
      return failure('Ancien mot de passe incorrect.');
    }
    final updated = User(
      id: user.id,
      fullName: user.fullName,
      email: user.email,
      passwordHash: _hash(newPassword),
      role: user.role,
      avatarSeed: user.avatarSeed,
      createdAt: user.createdAt,
    );
    await _dao.update(updated);
    if (currentUser?.id == user.id) currentUser = updated;
    return success(updated);
  }

  /// Hachage SHA-256 → hexadécimal.
  String _hash(String password) =>
      sha256.convert(password.codeUnits).toString();
}

/// Valeur de retour des opérations d'authentification.
class AuthResult {
  AuthResult._({required this.ok, this.user, this.message});
  final bool ok;
  final User? user;
  final String? message;
}
