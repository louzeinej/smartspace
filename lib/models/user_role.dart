import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Rôles disponibles dans SmartSpace (cahier des charges §2).
/// Le rôle est stocké en base sous forme d'index entier et est
/// réutilisé par les autres modules (ex. affectation d'une tâche
/// de charte graphique à un UI/UX Designer).
enum UserRole {
  scrumMaster('Scrum Master'),
  uiuxDesigner('UI/UX Designer'),
  developpeur('Développeur'),
  rh('RH'),
  employe('Employé'),
  administrateur('Administrateur');

  const UserRole(this.label);

  /// Libellé affiché dans l'interface.
  final String label;

  /// Icône représentant le rôle dans les listes.
  IconData get icon => switch (this) {
        UserRole.scrumMaster => Icons.flag_outlined,
        UserRole.uiuxDesigner => Icons.palette_outlined,
        UserRole.developpeur => Icons.code_outlined,
        UserRole.rh => Icons.groups_outlined,
        UserRole.employe => Icons.person_outline,
        UserRole.administrateur => Icons.admin_panel_settings_outlined,
      };

  /// Couleur du badge pilule associé au rôle.
  Color get badgeColor => switch (this) {
        UserRole.administrateur => AppColors.alert,
        UserRole.scrumMaster => AppColors.primary,
        UserRole.uiuxDesigner => const Color(0xFFB565D8),
        UserRole.developpeur => const Color(0xFF4A6CF7),
        UserRole.rh => const Color(0xFFE58E26),
        UserRole.employe => AppColors.success,
      };

  /// Conversion depuis l'entier stocké en base (colonnes SQLite typées).
  static UserRole fromIndex(int index) =>
      UserRole.values.firstWhere((r) => r.index == index,
          orElse: () => UserRole.employe);
}
