import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/role_badge.dart';
import '../models/publication.dart';
import '../services/link_preview_service.dart';
import '../ui/networking_style.dart';

/// Carte représentant une publication avec adaptation dynamique selon son type
/// (Sondage, Formation, Kudos, Annonce, Actualité, Marque-page, Lien Web).
class PublicationCard extends StatelessWidget {
  const PublicationCard({
    super.key,
    required this.publication,
    required this.currentUserId,
    required this.isAdministrator,
    required this.onLike,
    required this.onCommentTap,
    required this.onVotePoll,
    required this.onToggleEnroll,
    required this.onToggleBookmark,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
    required this.onShowParticipants,
  });

  final Publication publication;
  final int currentUserId;
  final bool isAdministrator;
  final VoidCallback onLike;
  final VoidCallback onCommentTap;
  final Function(int optionId) onVotePoll;
  final VoidCallback onToggleEnroll;
  final VoidCallback onToggleBookmark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;
  final VoidCallback onShowParticipants;

  bool get isAuthor => publication.utilisateurId == currentUserId;
  bool get canDelete => isAuthor || isAdministrator;

  @override
  Widget build(BuildContext context) {
    final isKudos = publication.type == PublicationType.kudos;
    final detectedUrl = LinkPreviewService.extractFirstUrl('${publication.titre} ${publication.contenu}');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: publication.isPinned
            ? Border.all(color: SsColors.primaire.withOpacity(0.5), width: 1.5)
            : Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête épinglé si applicable
          if (publication.isPinned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFFF3EDFF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.push_pin_rounded, size: 14, color: SsColors.primaire),
                  SizedBox(width: 6),
                  Text(
                    'Annonce Épinglée',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SsColors.primaire,
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line 1: Author, Badge, Options Menu
                _buildHeader(context),
                const SizedBox(height: 12),

                // Line 2: Type Badge & Title
                _buildTypeAndTitle(),
                const SizedBox(height: 8),

                // Line 3: Content Body
                Text(
                  publication.contenu,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF333333), height: 1.4),
                ),

                // Link Preview Card if a URL is detected
                if (detectedUrl != null) _buildLinkPreviewWidget(context, detectedUrl),

                const SizedBox(height: 12),

                // Line 4: Specific Rich Interactive Layouts
                if (publication.type == PublicationType.sondage) _buildPollWidget(context),
                if (publication.type == PublicationType.formation) _buildTrainingWidget(context),
                if (isKudos) _buildKudosCard(context),

                const Divider(height: 24, thickness: 0.8),

                // Line 5: Bottom Action Bar (Like, Comment, Bookmark, Stats)
                _buildActionBar(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final authorUser = User(
      id: publication.utilisateurId,
      fullName: publication.auteurNom ?? 'Utilisateur',
      email: publication.auteurEmail ?? 'user@smartspace.tn',
      passwordHash: '',
      role: publication.auteurRole ?? UserRole.employe,
      avatarSeed: publication.auteurAvatarSeed ?? 'seed',
      createdAt: DateTime.now(),
    );

    return Row(
      children: [
        AvatarWidget(user: authorUser, size: 42),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                publication.auteurNom ?? 'Utilisateur',
                style: SsText.titreCarte.copyWith(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  RoleBadge(role: publication.auteurRole ?? UserRole.employe, small: true),
                  const SizedBox(width: 8),
                  Text(
                    formatRelativeOrDate(publication.datePublication),
                    style: SsText.secondaire.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (isAdministrator || canDelete)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
            onSelected: (val) {
              if (val == 'edit') onEdit();
              if (val == 'delete') onDelete();
              if (val == 'pin') onTogglePin();
            },
            itemBuilder: (_) => [
              if (canDelete)
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: SsColors.secondaire),
                      SizedBox(width: 8),
                      Text('Éditer / Modifier'),
                    ],
                  ),
                ),
              if (isAdministrator)
                PopupMenuItem(
                  value: 'pin',
                  child: Row(
                    children: [
                      Icon(
                        publication.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(publication.isPinned ? 'Désépingler' : 'Épingler en haut'),
                    ],
                  ),
                ),
              if (canDelete)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: SsColors.alerte),
                      SizedBox(width: 8),
                      Text('Supprimer', style: TextStyle(color: SsColors.alerte)),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildTypeAndTitle() {
    final typeColor = PublicationType.colorOf(publication.type);
    final typeIcon = PublicationType.iconOf(publication.type);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(typeIcon, size: 14, color: typeColor),
              const SizedBox(width: 4),
              Text(
                publication.type,
                style: TextStyle(
                  color: typeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            publication.titre,
            style: SsText.titreCarte,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLinkPreviewWidget(BuildContext context, String url) {
    final domain = LinkPreviewService.extractDomain(url);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SsColors.primaire.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.language_rounded, color: SsColors.primaire, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lien Web • $domain',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: SsColors.primaire,
                  ),
                ),
                Text(
                  url,
                  style: const TextStyle(fontSize: 11, color: Colors.blueAccent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.open_in_new_rounded, size: 16, color: SsColors.primaire),
        ],
      ),
    );
  }

  Widget _buildPollWidget(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F8FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEBE7F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll_outlined, size: 18, color: SsColors.primaire),
              const SizedBox(width: 6),
              Text(
                'Sondage (${publication.totalPollVotes} votes)',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...publication.pollOptions.map((opt) {
            final double percentage = publication.totalPollVotes > 0
                ? (opt.votesCount / publication.totalPollVotes)
                : 0.0;
            final isVoted = publication.userVotedOptionId == opt.id;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  if (opt.id != null) onVotePoll(opt.id!);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isVoted ? SsColors.primaire : Colors.grey.shade300,
                      width: isVoted ? 1.5 : 1.0,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Progress fill bar
                      Positioned.fill(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: percentage,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isVoted
                                  ? SsColors.primaire.withOpacity(0.18)
                                  : Colors.grey.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            isVoted
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color: isVoted ? SsColors.primaire : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              opt.optionTexte,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isVoted ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                          Text(
                            '${(percentage * 100).toStringAsFixed(0)}% (${opt.votesCount})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isVoted ? SsColors.primaire : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTrainingWidget(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_rounded, color: Color(0xFF16A34A), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  publication.formationCompetence ?? 'Formation Professionnelle',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFF15803D), fontSize: 13),
                ),
              ),
            ],
          ),
          if (publication.formationDate != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.event_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  publication.formationDate!,
                  style: SsText.secondaire.copyWith(fontSize: 12),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onToggleEnroll,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: publication.isUserEnrolled
                        ? const Color(0xFF16A34A)
                        : Colors.white,
                    foregroundColor: publication.isUserEnrolled
                        ? Colors.white
                        : const Color(0xFF16A34A),
                    side: const BorderSide(color: Color(0xFF16A34A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(
                    publication.isUserEnrolled
                        ? Icons.check_rounded
                        : Icons.person_add_alt_1_rounded,
                    size: 18,
                  ),
                  label: Text(
                    publication.isUserEnrolled ? 'Inscrit(e)' : 'S\'inscrire',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
              if (isAdministrator ||
                  publication.auteurRole == UserRole.rh ||
                  isAuthor) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onShowParticipants,
                  tooltip: 'Voir les candidats (${publication.enrollmentsCount})',
                  icon: const Icon(Icons.group_outlined, color: Color(0xFF16A34A)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKudosCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF5F5), Color(0xFFFFE3E3)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC9C9)),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: Color(0xFFE53E3E), size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  publication.kudosBadge ?? '🌟 Bravo !',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC53030),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Distingué(e) : ${publication.kudosDestinataireNom ?? "Collègue"}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF742A2A),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Like Button
        InkWell(
          onTap: onLike,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Icon(
                  publication.isLikedByCurrentUser
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: publication.isLikedByCurrentUser
                      ? SsColors.alerte
                      : Colors.grey.shade600,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  '${publication.likesCount}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: publication.isLikedByCurrentUser
                        ? SsColors.alerte
                        : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Comments Button
        InkWell(
          onTap: onCommentTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, color: Colors.grey, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${publication.commentsCount}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bookmark Button
        InkWell(
          onTap: onToggleBookmark,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Icon(
              publication.isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: publication.isBookmarked
                  ? SsColors.primaire
                  : Colors.grey.shade600,
              size: 20,
            ),
          ),
        ),

        // Engagement score badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F0F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.orange),
              const SizedBox(width: 4),
              Text(
                '${publication.scoreTendance}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
