import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../widgets/avatar_widget.dart';
import '../models/publication.dart';
import '../services/networking_service.dart';
import '../ui/networking_style.dart';

/// Feuille de dialogue modale permettant de lire et rédiger des commentaires.
class CommentsBottomSheet extends StatefulWidget {
  const CommentsBottomSheet({
    super.key,
    required this.publication,
    required this.currentUserId,
    required this.isAdministrator,
    required this.service,
  });

  final Publication publication;
  final int currentUserId;
  final bool isAdministrator;
  final NetworkingService service;

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _commentCtrl = TextEditingController();
  List<PublicationComment> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    if (widget.publication.id == null) return;
    setState(() => _isLoading = true);
    final comments = await widget.service.getComments(widget.publication.id!);
    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || widget.publication.id == null) return;

    await widget.service.addComment(
      widget.publication.id!,
      widget.currentUserId,
      text,
    );

    _commentCtrl.clear();
    await _loadComments();
  }

  Future<void> _deleteComment(int commentId) async {
    await widget.service.deleteComment(commentId);
    await _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle indicator
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_rounded, color: SsColors.primaire),
                  const SizedBox(width: 8),
                  Text(
                    'Commentaires (${_comments.length})',
                    style: SsText.titreCarte,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Comments List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucun commentaire pour le moment.\nSoyez le premier à réagir !',
                            textAlign: TextAlign.center,
                            style: SsText.secondaire,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final com = _comments[index];
                            final isAuthor = com.utilisateurId == widget.currentUserId;
                            final canDelete = isAuthor || widget.isAdministrator;

                            final commentUser = User(
                              id: com.utilisateurId,
                              fullName: com.auteurNom ?? 'Utilisateur',
                              email: com.auteurEmail ?? 'email',
                              passwordHash: '',
                              role: com.auteurRole ?? UserRole.employe,
                              avatarSeed: com.auteurAvatarSeed ?? 'seed',
                              createdAt: DateTime.now(),
                            );

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AvatarWidget(user: commentUser, size: 36),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF7F7FB),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                com.auteurNom ?? 'Utilisateur',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Text(
                                                formatRelativeOrDate(com.dateCommentaire),
                                                style: SsText.secondaire.copyWith(fontSize: 10),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            com.commentaire,
                                            style: SsText.courant.copyWith(fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (canDelete && com.id != null)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18, color: SsColors.alerte),
                                      onPressed: () => _deleteComment(com.id!),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
            ),

            // Input Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      decoration: InputDecoration(
                        hintText: 'Écrire un commentaire...',
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: const Color(0xFFF7F7FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: SsColors.primaire,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.send_rounded, size: 20),
                    onPressed: _submitComment,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
