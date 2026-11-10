import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/role_badge.dart';
import '../services/networking_service.dart';
import '../ui/networking_style.dart';

/// Modal affichant le Tableau d'Honneur (Kudos Leaderboard) des collaborateurs les plus distingués.
class KudosLeaderboardSheet extends StatefulWidget {
  const KudosLeaderboardSheet({
    super.key,
    required this.service,
  });

  final NetworkingService service;

  @override
  State<KudosLeaderboardSheet> createState() => _KudosLeaderboardSheetState();
}

class _KudosLeaderboardSheetState extends State<KudosLeaderboardSheet> {
  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    final list = await widget.service.getKudosLeaderboard();
    if (mounted) {
      setState(() {
        _leaderboard = list;
        _isLoading = false;
      });
    }
  }

  String _getTrophyEmoji(int rank) {
    switch (rank) {
      case 0:
        return '🥇';
      case 1:
        return '🥈';
      case 2:
        return '🥉';
      default:
        return '🌟';
    }
  }

  Color _getTrophyBgColor(int rank) {
    switch (rank) {
      case 0:
        return const Color(0xFFFEF3C7);
      case 1:
        return const Color(0xFFF3F4F6);
      case 2:
        return const Color(0xFFFFEDD5);
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              const Text('Tableau d\'Honneur — Kudos', style: SsText.titreEcran),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Les collaborateurs les plus reconnus et félicités de l\'entreprise ce mois-ci 👏',
            style: SsText.secondaire,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _leaderboard.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun Kudos attribué pour le moment.\nSoyez le premier à féliciter un collègue !',
                          textAlign: TextAlign.center,
                          style: SsText.secondaire,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: _leaderboard.length,
                        itemBuilder: (context, index) {
                          final item = _leaderboard[index];
                          final rankEmoji = _getTrophyEmoji(index);
                          final cardBg = _getTrophyBgColor(index);

                          final roleEnum = UserRole.fromIndex((item['roleIndex'] as int?) ?? 4);

                          final u = User(
                            id: item['id'] as int?,
                            fullName: (item['nom'] as String?) ?? 'Utilisateur',
                            email: (item['email'] as String?) ?? 'email',
                            passwordHash: '',
                            role: roleEnum,
                            avatarSeed: (item['avatarSeed'] as String?) ?? 'seed',
                            createdAt: DateTime.now(),
                          );

                          final count = item['kudos_count'] as int;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: index < 3 ? Colors.amber.shade200 : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  rankEmoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 12),
                                AvatarWidget(user: u, size: 42),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        u.fullName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      RoleBadge(role: roleEnum, small: true),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: SsColors.primaire,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$count Kudos 🌟',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
