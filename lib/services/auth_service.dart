import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../database/user_dao.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import 'avatar_service.dart';
import 'email_otp_service.dart';
import 'verification_code_service.dart';

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
    required int securityQuestion,
    required String securityAnswer,
    bool allowAdminRole = false,
    String phone = '',
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
    // Le rôle Administrateur n'est autorisé que pour le premier compte
    // ou lorsqu'un Administrateur existant crée le compte (allowAdminRole).
    UserRole effectiveRole = role;
    if (userCount == 0) {
      effectiveRole = UserRole.administrateur;
    } else if (role == UserRole.administrateur && !allowAdminRole) {
      effectiveRole = UserRole.employe; // anti-escalade de privilèges
    }

    final user = User(
      fullName: fullName.trim(),
      email: normalizedEmail,
      passwordHash: _hash(password),
      role: effectiveRole,
      avatarSeed: AvatarService.randomSeed(),
      createdAt: DateTime.now(),
      securityQuestion: securityQuestion,
      // La réponse est normalisée (trim + minuscules) puis hachée,
      // comme le mot de passe.
      securityAnswerHash: _hash(securityAnswer.trim().toLowerCase()),
      phone: phone.trim(),
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
        securityQuestion: user.securityQuestion,
        securityAnswerHash: user.securityAnswerHash,
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
      securityQuestion: user.securityQuestion,
      securityAnswerHash: user.securityAnswerHash,
    );
    await _dao.update(updated);
    if (currentUser?.id == user.id) currentUser = updated;
    return success(updated);
  }

  // ── MOT DE PASSE OUBLIÉ ───────────────────────────────────────────
  // Codes de vérification en attente : email → (code, expiration).
  // Conservés en mémoire (jamais en base) et valables 10 minutes.
  static final Map<String, ({String code, DateTime expires})>
      _pendingCodes = {};
  static const _codeValidity = Duration(minutes: 10);

  /// Résout un identifiant de connexion/reset : email OU numéro de
  /// téléphone. Contient un « @ » → email, sinon → téléphone.
  Future<User?> _findByIdentifier(String identifier) {
    final id = identifier.trim();
    return id.contains('@')
        ? _dao.findByEmail(id)
        : _dao.findByPhone(id);
  }

  /// Demande un code de vérification pour un email OU un téléphone.
  /// Le code est généré par le web service random.org (valeur ajoutée),
  /// avec fallback local hors-ligne. Dans une vraie entreprise, il
  /// serait envoyé par email/SMS ; en démo, il est renvoyé à l'UI qui
  /// l'affiche dans une boîte de dialogue « simulation email/SMS ».
  Future<AuthResult> requestResetCode(String identifier) async {
    final user = await _findByIdentifier(identifier);
    if (user == null) {
      return failure('Aucun compte pour cet email ou ce numéro.');
    }
    final generated = await VerificationCodeService.generate();
    _pendingCodes[user.email] = (
      code: generated.code,
      expires: DateTime.now().add(_codeValidity),
    );

    // ENVOI RÉEL si une clé API email (Brevo) est configurée.
    // Sinon (ou en cas d'échec d'envoi), le code est renvoyé à l'UI
    // pour l'« email simulé » de la démo.
    final reallySent = await EmailOtpService.sendOtp(
      toEmail: user.email,
      toName: user.fullName,
      code: generated.code,
    );
    return AuthResult._(
      ok: true,
      user: user,
      // message = code quand il n'a PAS pu être envoyé (simulation),
      // null quand l'email réel est parti (l'UI ne l'affiche pas !).
      message: reallySent ? null : generated.code,
      sentByEmail: reallySent,
    );
  }

  /// Vérifie le code saisi pour un identifiant (email ou téléphone)
  /// donné. Les codes sont stockés sous l'email du compte.
  Future<bool> checkResetCode(String identifier, String code) async {
    final user = await _findByIdentifier(identifier);
    if (user == null) return false;
    final pending = _pendingCodes[user.email];
    if (pending == null) return false;
    if (DateTime.now().isAfter(pending.expires)) {
      _pendingCodes.remove(user.email);
      return false;
    }
    return pending.code == code.trim();
  }

  /// Réinitialisation par code vérifié : définit le nouveau mot de passe.
  Future<AuthResult> resetPasswordWithCode({
    required String identifier,
    required String code,
    required String newPassword,
  }) async {
    final user = await _findByIdentifier(identifier);
    if (user == null) {
      return failure('Aucun compte pour cet email ou ce numéro.');
    }
    if (!await checkResetCode(identifier, code)) {
      return failure('Code invalide ou expiré (validité 10 minutes).');
    }
    final updated = User(
      id: user.id,
      fullName: user.fullName,
      email: user.email,
      passwordHash: _hash(newPassword),
      role: user.role,
      avatarSeed: user.avatarSeed,
      createdAt: user.createdAt,
      securityQuestion: user.securityQuestion,
      securityAnswerHash: user.securityAnswerHash,
      phone: user.phone,
    );
    await _dao.update(updated);
    _pendingCodes.remove(user.email);
    return success(updated);
  }

  /// Étape 1 : retrouver la question secrète d'un compte par email
  /// (retourne null si le compte n'existe pas ou n'a pas de question).
  Future<int?> getSecurityQuestionFor(String identifier) async {
    final user = await _findByIdentifier(identifier);
    if (user == null || user.securityQuestion < 0) return null;
    return user.securityQuestion;
  }

  /// Étape 2 : vérifier la réponse et définir un nouveau mot de passe.
  Future<AuthResult> resetPassword({
    required String identifier,
    required String answer,
    required String newPassword,
  }) async {
    final user = await _findByIdentifier(identifier);
    if (user == null || user.securityQuestion < 0) {
      return failure('Aucune question secrète pour ce compte.');
    }
    if (user.securityAnswerHash !=
        _hash(answer.trim().toLowerCase())) {
      return failure('Réponse incorrecte.');
    }
    final updated = User(
      id: user.id,
      fullName: user.fullName,
      email: user.email,
      passwordHash: _hash(newPassword),
      role: user.role,
      avatarSeed: user.avatarSeed,
      createdAt: user.createdAt,
      securityQuestion: user.securityQuestion,
      securityAnswerHash: user.securityAnswerHash,
      phone: user.phone,
    );
    await _dao.update(updated);
    return success(updated);
  }

  /// Hachage SHA-256 → hexadécimal.
  String _hash(String password) =>
      sha256.convert(password.codeUnits).toString();
}

/// Valeur de retour des opérations d'authentification.
class AuthResult {
  AuthResult._({
    required this.ok,
    this.user,
    this.message,
    this.sentByEmail = false,
  });
  final bool ok;
  final User? user;
  final String? message;

  /// Vrai si le code a réellement été envoyé par email (API Brevo) :
  /// l'UI doit alors MASQUER le code et inviter à consulter sa boîte.
  final bool sentByEmail;
}
