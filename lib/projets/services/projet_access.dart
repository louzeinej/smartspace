import '../../core/module_access.dart';
import '../../core/session.dart';
import '../../models/user_role.dart';
import '../models/projet.dart';
import '../models/tache.dart';

/// Utilisateur qui effectue une action.
class Acteur {
  final int utilisateurId;
  final UserRole role;

  const Acteur({required this.utilisateurId, required this.role});

  factory Acteur.depuisSession() =>
      Acteur(utilisateurId: Session.utilisateurId, role: Session.roleEnum);

  bool get estAdmin => role == UserRole.administrateur;
}

/// Droits du module Projets et Tâches : toutes les vérifications passent ici.
abstract final class ProjetAccess {
  /// Créer un projet : règle d'équipe définie dans [ModuleAccess].
  static bool peutCreerProjet(UserRole role) =>
      ModuleAccess.canCreateProject(role);

  /// Modifier ou supprimer un projet, gérer ses tâches et les affecter :
  /// réservé au créateur du projet et aux administrateurs.
  static bool peutGererProjet(
    Projet projet, {
    required int utilisateurId,
    required bool estAdmin,
  }) =>
      estAdmin || projet.createurId == utilisateurId;

  /// Changer le statut d'une tâche : la personne affectée, ou quiconque
  /// peut gérer le projet.
  static bool peutChangerStatut(
    Tache tache,
    Projet projet, {
    required int utilisateurId,
    required bool estAdmin,
  }) =>
      tache.utilisateurId == utilisateurId ||
      peutGererProjet(projet, utilisateurId: utilisateurId, estAdmin: estAdmin);
}
