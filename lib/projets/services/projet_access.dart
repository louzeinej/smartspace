import '../../core/module_access.dart';
import '../../models/user_role.dart';
import '../models/projet.dart';

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
}
