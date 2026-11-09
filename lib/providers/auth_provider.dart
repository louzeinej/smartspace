import 'package:flutter/foundation.dart';

import '../core/session.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';

/// État réactif de la session (package `provider`).
///
/// Toute l'application écoute [AuthProvider] : quand l'utilisateur se
/// connecte/déconnecte, les écrans se rebuild automatiquement — pas de
/// `setState` éparpillés ni de passage de callbacks entre widgets.
class AuthProvider extends ChangeNotifier {
  final AuthService _auth = AuthService.instance;

  /// Utilisateur connecté (null → écrans de connexion).
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  /// Vrai si l'utilisateur connecté peut supprimer des comptes
  /// (règle d'accès métier : Administrateur uniquement).
  bool get canDeleteAccounts =>
      currentUser?.role == UserRole.administrateur;

  Future<void> restoreSession() async {
    await _auth.restoreSession();
    notifyListeners();
  }

  Future<AuthResult> login(String email, String password) async {
    final res = await _auth.login(email, password);
    if (res.ok) {
      // Alimente la Session partagée avec les autres modules
      // (Réservations lit utilisateurId et estAdmin).
      Session.connecter(
        id: res.user!.id!,
        nom: res.user!.fullName,
        role: res.user!.role.label,
      );
      notifyListeners();
    }
    return res;
  }

  /// Inscription publique : le rôle Administrateur est refusé
  /// (garde anti-escalade côté service).
  Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    required int securityQuestion,
    required String securityAnswer,
  }) {
    return _auth.register(
      fullName: fullName,
      email: email,
      password: password,
      role: role,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
    );
  }

  /// Création d'un compte PAR UN ADMINISTRATEUR (écran annuaire) :
  /// l'admin peut attribuer n'importe quel rôle, y compris Administrateur.
  Future<AuthResult> adminCreateUser({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    required int securityQuestion,
    required String securityAnswer,
  }) {
    return _auth.register(
      fullName: fullName,
      email: email,
      password: password,
      role: role,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
      allowAdminRole: Session.estAdmin,
    );
  }

  /// « Mot de passe oublié » : question secrète du compte, puis reset.
  Future<int?> securityQuestionFor(String email) =>
      _auth.getSecurityQuestionFor(email);

  /// Mot de passe oublié — méthode « code de vérification » (API).
  Future<AuthResult> requestResetCode(String email) =>
      _auth.requestResetCode(email);

  Future<AuthResult> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) =>
      _auth.resetPasswordWithCode(
          email: email, code: code, newPassword: newPassword);

  Future<AuthResult> resetPassword({
    required String email,
    required String answer,
    required String newPassword,
  }) =>
      _auth.resetPassword(
          email: email, answer: answer, newPassword: newPassword);

  Future<AuthResult> changePassword(
      User user, String oldPassword, String newPassword) {
    return _auth.changePassword(user, oldPassword, newPassword);
  }

  Future<void> logout() async {
    await _auth.logout();
    Session.deconnecter();
    notifyListeners();
  }

  /// Recharge l'utilisateur connecté après modification de son profil.
  Future<void> refreshCurrentUser(int userId) async {
    final fresh = await AuthService.instance.restoreById(userId);
    if (fresh != null) {
      AuthService.instance.currentUser = fresh;
      notifyListeners();
    }
  }
}
