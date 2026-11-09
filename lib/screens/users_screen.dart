import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../database/user_dao.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/user_card.dart';
import 'assistant_screen.dart';
import 'edit_user_screen.dart';
import 'login_screen.dart';
import 'user_detail_screen.dart';

/// Écran principal du module : annuaire des utilisateurs avec
/// recherche, filtre par rôle et statistiques de répartition.
/// Données chargées en asynchrone via FutureBuilder + refresh manuel.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String _search = '';
  UserRole? _roleFilter;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final me = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Utilisateurs'),
        actions: [
          IconButton(
            tooltip: 'Assistant SmartSpace',
            icon: const Icon(Icons.auto_awesome_rounded,
                color: AppColors.primary),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AssistantScreen())),
          ),
          IconButton(
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
        ],
      ),
      // Création de comptes : privilège Administrateur uniquement.
      floatingActionButton: auth.canDeleteAccounts
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Ajouter',
                  style: TextStyle(fontSize: 13)),
              onPressed: () async {
                final created = await Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const EditUserScreen()));
                if (created == true) setState(() {});
              },
            )
          : null,
      body: Column(
        children: [
          // ── Bandeau profil connecté ──
          if (me != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded,
                      color: Colors.white, size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(me.fullName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(
                          'Connecté · ${me.role.label}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                UserDetailScreen(userId: me.id!))),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    child: const Text('Mon profil'),
                  ),
                ],
              ),
            ),

          // ── Recherche + filtres ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Rechercher par nom ou email…',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _roleChip(null, 'Tous'),
                for (final role in UserRole.values) _roleChip(role, role.label),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // ── Liste (FutureBuilder + ListView.builder) ──
          Expanded(
            child: FutureBuilder<List<User>>(
              key: ValueKey('$_search|${_roleFilter?.index}'),
              future: _loadUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary));
                }
                if (snapshot.hasError) {
                  return _message('Erreur de chargement : ${snapshot.error}');
                }
                final users = snapshot.data ?? [];
                if (users.isEmpty) {
                  return _message('Aucun utilisateur trouvé.',
                      icon: Icons.person_search_rounded);
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => setState(() {}),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: users.length,
                    itemBuilder: (context, i) => UserCard(
                      user: users[i],
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (_) => UserDetailScreen(
                                  userId: users[i].id!)))
                          .then((_) => setState(() {})),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Charge la liste : recherche SQL si terme saisi, puis filtre rôle
  /// en Dart (combiner LIKE + GROUP BY aurait complexifié la requête
  /// sans gain mesurable sur une base locale).
  Future<List<User>> _loadUsers() async {
    final users = _search.trim().isEmpty
        ? await UserDao.instance.getAll()
        : await UserDao.instance.search(_search);
    if (_roleFilter == null) return users;
    return users.where((u) => u.role == _roleFilter).toList();
  }

  Widget _roleChip(UserRole? role, String label) {
    final selected = _roleFilter == role;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label,
            style: TextStyle(
                fontSize: 12,
                color:
                    selected ? Colors.white : AppColors.secondary)),
        selected: selected,
        onSelected: (_) => setState(() => _roleFilter = role),
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        side: BorderSide(
            color: selected ? AppColors.primary : const Color(0xFFD9D9E3)),
        showCheckmark: false,
      ),
    );
  }

  Widget _message(String text, {IconData icon = Icons.inbox_rounded}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 46, color: AppColors.secondary.withValues(alpha: 0.3)),
          const SizedBox(height: 10),
          Text(text,
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondary.withValues(alpha: 0.55))),
        ],
      ),
    );
  }
}

/// Formatage de date FR, partagé par les écrans de détail/édition.
String formatDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
