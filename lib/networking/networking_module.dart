import 'package:flutter/material.dart';
import '../core/session.dart';
import '../models/user_role.dart';
import 'models/publication.dart';
import 'services/networking_service.dart';
import 'ui/networking_style.dart';
import 'widgets/comments_bottom_sheet.dart';
import 'widgets/create_publication_sheet.dart';
import 'widgets/publication_card.dart';

/// Module principal « Gestion Networking » (Réseau social interne / Mini-LinkedIn).
class NetworkingModule extends StatefulWidget {
  const NetworkingModule({
    super.key,
    required this.utilisateurId,
    required this.estAdmin,
    this.service,
  });

  final int utilisateurId;
  final bool estAdmin;
  final NetworkingService? service;

  @override
  State<NetworkingModule> createState() => _NetworkingModuleState();
}

class _NetworkingModuleState extends State<NetworkingModule> {
  late final NetworkingService _service = widget.service ?? NetworkingService();

  final TextEditingController _searchCtrl = TextEditingController();
  List<Publication> _publications = [];
  bool _isLoading = true;

  String _filterType = 'Tout';
  String _sortBy = 'recent'; // 'recent' ou 'tendance'

  final List<String> _filters = [
    'Tout',
    'Annonces 📌',
    'Actualités',
    'Formations 🎓',
    'Sondages 📊',
    'Kudos 🌟',
  ];

  @override
  void initState() {
    super.initState();
    _chargerPublications();
  }

  Future<void> _chargerPublications() async {
    setState(() => _isLoading = true);
    final list = await _service.getPublications(
      filterType: _filterType,
      searchQuery: _searchCtrl.text,
      sortBy: _sortBy,
      currentUserId: widget.utilisateurId,
    );

    if (mounted) {
      setState(() {
        _publications = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLike(Publication pub) async {
    if (pub.id == null) return;
    await _service.toggleLike(pub.id!, widget.utilisateurId);
    await _chargerPublications();
  }

  Future<void> _handleVotePoll(Publication pub, int optionId) async {
    if (pub.id == null) return;
    await _service.votePollOption(pub.id!, optionId, widget.utilisateurId);
    await _chargerPublications();
  }

  Future<void> _handleToggleEnroll(Publication pub) async {
    if (pub.id == null) return;
    final isEnrolled = await _service.toggleTrainingEnrollment(
      pub.id!,
      widget.utilisateurId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEnrolled
                ? 'Inscription enregistrée pour la formation !'
                : 'Inscription annulée.',
          ),
          backgroundColor: isEnrolled ? SsColors.succes : Colors.orange,
        ),
      );
    }
    await _chargerPublications();
  }

  Future<void> _handleDelete(Publication pub) async {
    if (pub.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer cette publication ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SsColors.alerte),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.deletePublication(pub.id!);
      await _chargerPublications();
    }
  }

  Future<void> _handleTogglePin(Publication pub) async {
    if (pub.id == null) return;
    await _service.togglePin(pub.id!, pub.isPinned);
    await _chargerPublications();
  }

  void _openComments(Publication pub) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsBottomSheet(
        publication: pub,
        currentUserId: widget.utilisateurId,
        isAdministrator: widget.estAdmin,
        service: _service,
      ),
    ).then((_) => _chargerPublications());
  }

  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreatePublicationSheet(
        currentUserId: widget.utilisateurId,
        isAdministrator: widget.estAdmin,
        service: _service,
        onCreated: _chargerPublications,
      ),
    );
  }

  void _openEditSheet(Publication pub) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreatePublicationSheet(
        currentUserId: widget.utilisateurId,
        isAdministrator: widget.estAdmin,
        service: _service,
        publicationToEdit: pub,
        onCreated: _chargerPublications,
      ),
    );
  }

  void _showParticipantsModal(Publication pub) async {
    if (pub.id == null) return;
    final list = await _service.getTrainingParticipants(pub.id!);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Participants inscrits (${list.length})'),
        content: SizedBox(
          width: double.maxFinite,
          child: list.isEmpty
              ? const Text('Aucun participant inscrit pour le moment.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final item = list[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: SsColors.primaire,
                        child: Text(
                          (item['nom'] as String).isNotEmpty
                              ? (item['nom'] as String)[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text((item['nom'] as String?) ?? 'Utilisateur'),
                      subtitle: Text(
                        "${item['email']} • ${UserRole.fromIndex((item['roleIndex'] as int?) ?? 4).label}",
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SsColors.fond,
      appBar: AppBar(
        backgroundColor: SsColors.primaire,
        foregroundColor: Colors.white,
        title: const Text('Réseau Interne SmartSpace'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, color: Colors.white),
            tooltip: 'Trier par',
            onSelected: (val) {
              setState(() => _sortBy = val);
              _chargerPublications();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'recent',
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Plus récents d\'abord'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'tendance',
                child: Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Tendances & Popularité'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        backgroundColor: SsColors.primaire,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('Publier', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _chargerPublications(),
              decoration: InputDecoration(
                hintText: 'Rechercher une publication, annonce, formation...',
                prefixIcon: const Icon(Icons.search_rounded, color: SsColors.primaire),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          _chargerPublications();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF7F7FB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Chips de filtres par catégorie
          Container(
            color: Colors.white,
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _filterType == filter;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    selectedColor: SsColors.primaire,
                    backgroundColor: const Color(0xFFF0EDFA),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : SsColors.secondaire,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _filterType = filter);
                        _chargerPublications();
                      }
                    },
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),

          // Contenu principal / Feed
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _chargerPublications,
                    child: _publications.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.forum_outlined, size: 64, color: Colors.grey),
                                    SizedBox(height: 12),
                                    Text(
                                      'Aucune publication trouvée.\nSoyez le premier à publier !',
                                      textAlign: TextAlign.center,
                                      style: SsText.secondaire,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(14),
                            itemCount: _publications.length,
                            itemBuilder: (context, index) {
                              final pub = _publications[index];
                              return PublicationCard(
                                publication: pub,
                                currentUserId: widget.utilisateurId,
                                isAdministrator: widget.estAdmin,
                                onLike: () => _handleLike(pub),
                                onCommentTap: () => _openComments(pub),
                                onVotePoll: (optId) => _handleVotePoll(pub, optId),
                                onToggleEnroll: () => _handleToggleEnroll(pub),
                                onEdit: () => _openEditSheet(pub),
                                onDelete: () => _handleDelete(pub),
                                onTogglePin: () => _handleTogglePin(pub),
                                onShowParticipants: () => _showParticipantsModal(pub),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
