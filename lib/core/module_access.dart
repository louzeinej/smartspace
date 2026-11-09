import '../models/user_role.dart';

/// GESTION DES RÔLES — source unique de vérité pour toute l'application.
///
/// Les 5 onglets restent visibles par tout utilisateur connecté (ce
/// sont des fonctionnalités, cf. cahier des charges) ; ce qui est
/// restreint, ce sont les ACTIONS de chaque module. Chaque module
/// (actuel ou à venir) DOIT interroger cette classe plutôt que de
/// comparer les rôles à la main — ainsi les règles sont cohérentes
/// et modifiables en un seul endroit.
///
/// Règles dérivées du cahier des charges :
///  - Admin référence les salles ; tout utilisateur réserve ;
///  - Scrum Master crée les projets / tâches ;
///  - seul l'Admin gère les comptes et les rôles.
abstract final class ModuleAccess {
  // ── Module Utilisateurs (Youssef Messoudi) ─────────────────────────
  /// Créer un compte, supprimer, promouvoir/rétrograder.
  static bool canManageUsers(UserRole role) =>
      role == UserRole.administrateur;

  // ── Module Projets & Tâches (Youssef Sghaier) ──────────────────────
  /// Créer un projet et affecter des tâches (Scrum Master ou Admin).
  static bool canCreateProject(UserRole role) =>
      role == UserRole.scrumMaster || role == UserRole.administrateur;

  // ── Module Réservations de Salles (Youssef Fadaoui) ────────────────
  /// Référencer / modifier les salles (Admin).
  static bool canManageRooms(UserRole role) =>
      role == UserRole.administrateur;

  /// Réserver une salle : tout utilisateur authentifié.
  static bool canReserveRoom(UserRole role) => true;

  // ── Module Networking (Manar Kalai) ────────────────────────────────
  /// Publier une actualité : tout utilisateur authentifié.
  static bool canPostNetwork(UserRole role) => true;

  // ── Module Événements & Club (Louzeine Aloui) ──────────────────────
  /// Organiser un événement / une activité de club (Admin ou RH).
  static bool canManageActivities(UserRole role) =>
      role == UserRole.administrateur || role == UserRole.rh;

  /// S'inscrire à une activité : tout utilisateur authentifié.
  static bool canJoinActivity(UserRole role) => true;

  /// Matrice des permissions par rôle — alimente l'écran « Gestion des
  /// rôles » et sert de documentation vivante des règles.
  static Map<String, bool> permissionsOf(UserRole role) => {
        'Gérer les comptes et les rôles': canManageUsers(role),
        'Créer des projets / affecter des tâches': canCreateProject(role),
        'Référencer des salles': canManageRooms(role),
        'Réserver une salle': canReserveRoom(role),
        'Publier sur le réseau interne': canPostNetwork(role),
        'Organiser des événements / clubs': canManageActivities(role),
        "S'inscrire à une activité": canJoinActivity(role),
      };
}
