import '../models/user_role.dart';

/// Utilisateur connecté, partagé par tous les modules.
///
/// Rempli par le module Utilisateurs (Youssef Messoudi) après la
/// connexion. Les modules lisent [roleEnum] et interrogent
/// [ModuleAccess] (core/module_access.dart) pour leurs droits.
class Session {
  Session._();

  static int utilisateurId = 0;
  static String nom = '';
  static String role = '';
  static int roleIndex = UserRole.employe.index;

  /// Rôle typé, pour interroger ModuleAccess.
  static UserRole get roleEnum => UserRole.fromIndex(roleIndex);

  static bool get estAdmin => roleEnum == UserRole.administrateur;

  static void connecter({
    required int id,
    required String nom,
    required String role,
    int? roleIndex,
  }) {
    utilisateurId = id;
    Session.nom = nom;
    Session.role = role;
    Session.roleIndex = roleIndex ?? UserRole.employe.index;
  }

  /// Appelée par le module Utilisateurs à la déconnexion.
  static void deconnecter() {
    utilisateurId = 0;
    nom = '';
    role = '';
    roleIndex = UserRole.employe.index;
  }
}
