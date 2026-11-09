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

  Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    return _auth.register(
        fullName: fullName, email: email, password: password, role: role);
  }

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
