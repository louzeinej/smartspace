import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/user_dao.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/avatar_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/gradient_button.dart';
import '../widgets/role_badge.dart';
import 'edit_user_screen.dart';
import 'users_screen.dart';

/// Profil détaillé d'un utilisateur : avatar (web service DiceBear),
/// badge de rôle, informations, édition, changement de mot de passe,
/// suppression (Administrateur uniquement — règle d'accès métier).
class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key, required this.userId});

  final int userId;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  late Future<User?> _future;
  bool _apiOnline = false;

  @override
  void initState() {
    super.initState();
    _reload();
    // Valeur ajoutée : indique si le web service d'avatars est joignable.
    AvatarService.isReachable()
        .then((ok) => mounted ? setState(() => _apiOnline = ok) : null);
  }

  void _reload() {
    // Corps de bloc (et non flèche) : la closure ne doit rien RETOURNER,
    // sinon setState reçoit un Future → crash « callback returned a Future ».
    setState(() {
      _future = UserDao.instance.findById(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final me = auth.currentUser;
    final isAdmin = auth.canManageUsers;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil utilisateur')),
      body: FutureBuilder<User?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          final user = snapshot.data;
          if (user == null) {
            return const Center(child: Text('Utilisateur introuvable.'));
          }
          final isSelf = me?.id == user.id;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ── Carte identité ──
                Hero(
                  tag: 'avatar-${user.id}',
                  child: AvatarWidget(user: user, size: 110),
                ),
                const SizedBox(height: 14),
                Text(user.fullName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                RoleBadge(role: user.role),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _apiOnline
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
                      size: 14,
                      color: _apiOnline ? AppColors.success : AppColors.alert,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _apiOnline
                          ? 'Avatar servi par l\'API DiceBear'
                          : 'Hors-ligne — initiales affichées',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.secondary.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Informations ──
                _infoTile(Icons.mail_outline_rounded, 'Email', user.email),
                _infoTile(Icons.phone_outlined, 'Téléphone',
                    user.phone.isEmpty ? 'Non renseigné' : user.phone),
                _infoTile(Icons.badge_outlined, 'Rôle', user.role.label),
                _infoTile(Icons.calendar_today_outlined, 'Membre depuis',
                    formatDate(user.createdAt)),
                _infoTile(Icons.key_rounded, 'Mot de passe',
                    '•••••••• (haché SHA-256 en base)'),
                const SizedBox(height: 26),

                // ── Actions ──
                GradientButton(
                  label: isSelf
                      ? 'Modifier mon profil'
                      : 'Modifier ce profil',
                  icon: Icons.edit_rounded,
                  onPressed: () async {
                    // Context capturé AVANT l'await (règle lint
                    // use_build_context_synchronously).
                    final provider = context.read<AuthProvider>();
                    final changed = await Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                EditUserScreen(user: user, editPassword: false)));
                    if (changed == true && mounted) {
                      await provider.refreshCurrentUser(user.id!);
                      _reload();
                    }
                  },
                ),
                const SizedBox(height: 12),
                GradientButton(
                  label: 'Changer le mot de passe',
                  icon: Icons.password_rounded,
                  onPressed: () async {
                    final changed = await Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                EditUserScreen(user: user, editPassword: true)));
                    if (changed == true && mounted) _reload();
                  },
                ),

                // Suppression : Administrateur uniquement + interdiction
                // de supprimer son propre compte (règles d'accès métier).
                if (isAdmin && !isSelf) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.alert,
                        side: const BorderSide(color: AppColors.alert),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Supprimer ce compte'),
                      onPressed: () => _confirmDelete(user),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.secondary.withValues(alpha: 0.5))),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.secondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce compte ?'),
        content: Text(
            'Le compte de ${user.fullName} sera définitivement supprimé '
            'de la base locale.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: AppColors.alert))),
        ],
      ),
    );
    if (confirmed != true) return;
    await UserDao.instance.delete(user.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Compte de ${user.fullName} supprimé.'),
      backgroundColor: AppColors.success,
    ));
    Navigator.of(context).pop(true);
  }
}
