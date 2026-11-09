import 'package:flutter/material.dart';

import '../core/module_access.dart';
import '../core/session.dart';
import '../database/user_dao.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_widget.dart';

/// Écran ADMINISTRATEUR « Gestion des rôles » :
///  1. matrice des permissions par rôle (source : ModuleAccess) ;
///  2. liste des comptes avec changement de rôle en un geste
///     (promotion / rétrogradation), interdit sur son propre compte
///     pour éviter de se verrouiller soi-même dehors.
class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  late Future<List<User>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() =>
      setState(() => _future = UserDao.instance.getAll());

  Future<void> _changeRole(User user, UserRole newRole) async {
    if (newRole == user.role) return;
    if (user.id == Session.utilisateurId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Impossible de modifier son propre rôle (sécurité).'),
        backgroundColor: AppColors.alert,
      ));
      return;
    }
    final updated = User(
      id: user.id,
      fullName: user.fullName,
      email: user.email,
      passwordHash: user.passwordHash,
      role: newRole,
      avatarSeed: user.avatarSeed,
      createdAt: user.createdAt,
      securityQuestion: user.securityQuestion,
      securityAnswerHash: user.securityAnswerHash,
      phone: user.phone,
    );
    await UserDao.instance.update(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text('${user.fullName} est maintenant ${newRole.label}.'),
      backgroundColor: AppColors.success,
    ));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestion des rôles'),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Comptes', icon: Icon(Icons.groups_outlined)),
              Tab(text: 'Permissions', icon: Icon(Icons.fact_check_outlined)),
            ],
          ),
        ),
        body: TabBarView(
          children: [_accountsTab(), _permissionsTab()],
        ),
      ),
    );
  }

  // ── Onglet 1 : comptes + changement de rôle inline ────────────────
  Widget _accountsTab() {
    return FutureBuilder<List<User>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
                  CircularProgressIndicator(color: AppColors.primary));
        }
        final users = snapshot.data ?? [];
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, i) {
            final u = users[i];
            final isSelf = u.id == Session.utilisateurId;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  AvatarWidget(user: u, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.fullName,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.secondary)),
                        Text(
                          isSelf ? '${u.email} (vous)' : u.email,
                          style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.secondary
                                  .withValues(alpha: 0.55))),
                      ],
                    ),
                  ),
                  // Changement de rôle direct — désactivé sur soi-même.
                  DropdownButton<UserRole>(
                    value: u.role,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(12),
                    items: [
                      for (final r in UserRole.values)
                        DropdownMenuItem(
                          value: r,
                          child: Text(r.label,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: r.badgeColor,
                                  fontWeight: FontWeight.w500)),
                        ),
                    ],
                    onChanged:
                        isSelf ? null : (r) => r != null ? _changeRole(u, r) : null,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Onglet 2 : matrice des permissions par rôle ───────────────────
  Widget _permissionsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Règles appliquées par ModuleAccess (core/module_access.dart) — '
          'source unique partagée par les 5 modules.',
          style: TextStyle(
              fontSize: 12,
              color: AppColors.secondary.withValues(alpha: 0.55))),
        const SizedBox(height: 12),
        for (final role in UserRole.values)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Theme(
              // Accent du tile aligné sur la charte.
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 14),
                childrenPadding:
                    const EdgeInsets.fromLTRB(14, 0, 14, 14),
                leading: CircleAvatar(
                  radius: 17,
                  backgroundColor: role.badgeColor,
                  child: Icon(role.icon,
                      size: 17, color: Colors.white),
                ),
                title: Text(role.label,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.secondary)),
                subtitle: Text(
                  '${ModuleAccess.permissionsOf(role).values.where((v) => v).length} permissions',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.secondary
                          .withValues(alpha: 0.55))),
                children: [
                  for (final entry in ModuleAccess.permissionsOf(role).entries)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(
                            entry.value
                                ? Icons.check_circle_rounded
                                : Icons.remove_circle_outline_rounded,
                            size: 17,
                            color: entry.value
                                ? AppColors.success
                                : AppColors.secondary.withValues(alpha: 0.3),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 13,
                                color: entry.value
                                    ? AppColors.secondary
                                    : AppColors.secondary
                                        .withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
