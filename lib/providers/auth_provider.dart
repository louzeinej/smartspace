import 'package:flutter/foundation.dart';

import '../core/module_access.dart';
import '../modules/evenements/entities/utilisateur_courant.dart';
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

  /// Droits de l'utilisateur connecté — délégués à ModuleAccess
  /// (source unique de vérité, partagée avec les autres modules).
  bool get canManageUsers =>
      ModuleAccess.canManageUsers(currentUser?.role ?? UserRole.employe);

  bool get canCreateProject =>
      ModuleAccess.canCreateProject(currentUser?.role ?? UserRole.employe);

  bool get canManageRooms =>
      ModuleAccess.canManageRooms(currentUser?.role ?? UserRole.employe);

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
        roleIndex: res.user!.role.index,
      );
      // Module Événements : son API lit l'id de l'utilisateur courant.
      await UtilisateurCourant.changer(res.user!.id!);
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
    String phone = '',
  }) {
    return _auth.register(
      fullName: fullName,
      email: email,
      password: password,
      role: role,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
      phone: phone,
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
    String phone = '',
  }) {
    return _auth.register(
      fullName: fullName,
      email: email,
      password: password,
      role: role,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
      allowAdminRole: Session.estAdmin,
      phone: phone,
    );
  }

  /// « Mot de passe oublié » : question secrète du compte, puis reset.
  Future<int?> securityQuestionFor(String identifier) =>
      _auth.getSecurityQuestionFor(identifier);

  /// Mot de passe oublié — méthode « code de vérification » (API).
  Future<AuthResult> requestResetCode(String identifier) =>
      _auth.requestResetCode(identifier);

  Future<AuthResult> resetPasswordWithCode({
    required String identifier,
    required String code,
    required String newPassword,
  }) =>
      _auth.resetPasswordWithCode(
          identifier: identifier, code: code, newPassword: newPassword);

  Future<AuthResult> resetPassword({
    required String identifier,
    required String answer,
    required String newPassword,
  }) =>
      _auth.resetPassword(
          identifier: identifier, answer: answer, newPassword: newPassword);

  Future<AuthResult> changePassword(
      User user, String oldPassword, String newPassword) {
    return _auth.changePassword(user, oldPassword, newPassword);
  }

  Future<void> logout() async {
    await _auth.logout();
    Session.deconnecter();
    // Module Événements : réinitialise l'employé courant.
    await UtilisateurCourant.changer(1);
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
