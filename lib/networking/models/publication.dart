import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../ui/networking_style.dart';

/// Types de publications disponibles dans le réseau interne SmartSpace.
class PublicationType {
  static const String actualite = 'Actualité';
  static const String annonce = 'Annonce';
  static const String formation = 'Formation';
  static const String sondage = 'Sondage';
  static const String kudos = 'Kudos';

  static List<String> get tous => [actualite, annonce, formation, sondage, kudos];

  static IconData iconOf(String type) {
    switch (type) {
      case annonce:
        return Icons.campaign_rounded;
      case formation:
        return Icons.school_rounded;
      case sondage:
        return Icons.poll_rounded;
      case kudos:
        return Icons.military_tech_rounded;
      case actualite:
      default:
        return Icons.article_rounded;
    }
  }

  static Color colorOf(String type) {
    switch (type) {
      case annonce:
        return const Color(0xFFFF9F43);
      case formation:
        return const Color(0xFF00CFE8);
      case sondage:
        return const Color(0xFF7367F0);
      case kudos:
        return const Color(0xFFEA5455);
      case actualite:
      default:
        return const Color(0xFF28C76F);
    }
  }
}

/// Option d'un sondage interactif.
class PollOption {
  final int? id;
  final int publicationId;
  final String optionTexte;
  final int votesCount;

  PollOption({
    this.id,
    required this.publicationId,
    required this.optionTexte,
    this.votesCount = 0,
  });

  factory PollOption.fromMap(Map<String, dynamic> map) {
    return PollOption(
      id: map['id'] as int?,
      publicationId: map['publication_id'] as int,
      optionTexte: map['option_texte'] as String,
      votesCount: (map['votes_count'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'publication_id': publicationId,
      'option_texte': optionTexte,
      'votes_count': votesCount,
    };
  }
}

/// Commentaire sur une publication.
class PublicationComment {
  final int? id;
  final int publicationId;
  final int utilisateurId;
  final String commentaire;
  final String dateCommentaire;
  final String? auteurNom;
  final String? auteurEmail;
  final UserRole? auteurRole;
  final String? auteurAvatarSeed;

  PublicationComment({
    this.id,
    required this.publicationId,
    required this.utilisateurId,
    required this.commentaire,
    required this.dateCommentaire,
    this.auteurNom,
    this.auteurEmail,
    this.auteurRole,
    this.auteurAvatarSeed,
  });

  factory PublicationComment.fromMap(Map<String, dynamic> map) {
    UserRole? role;
    if (map['auteur_role_index'] != null) {
      try {
        role = UserRole.fromIndex(map['auteur_role_index'] as int);
      } catch (_) {}
    }

    return PublicationComment(
      id: map['id'] as int?,
      publicationId: map['publication_id'] as int,
      utilisateurId: map['utilisateur_id'] as int,
      commentaire: map['commentaire'] as String,
      dateCommentaire: map['date_commentaire'] as String,
      auteurNom: map['auteur_nom'] as String?,
      auteurEmail: map['auteur_email'] as String?,
      auteurRole: role,
      auteurAvatarSeed: map['auteur_avatar_seed'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'publication_id': publicationId,
      'utilisateur_id': utilisateurId,
      'commentaire': commentaire,
      'date_commentaire': dateCommentaire,
    };
  }
}

/// Modèle principal d'une publication du réseau interne.
class Publication {
  final int? id;
  final int utilisateurId;
  final String titre;
  final String contenu;
  final String type;
  final String datePublication;
  final bool isPinned;
  final int likesCount;
  final int commentsCount;
  final bool isLikedByCurrentUser;
  final bool isBookmarked;

  // Author details (from JOIN)
  final String? auteurNom;
  final String? auteurEmail;
  final UserRole? auteurRole;
  final String? auteurAvatarSeed;

  // Kudos specifics
  final int? kudosDestinataireId;
  final String? kudosDestinataireNom;
  final String? kudosBadge;

  // Formation specifics
  final String? formationDate;
  final String? formationCompetence;
  final bool isUserEnrolled;
  final int enrollmentsCount;

  // Poll specifics
  final List<PollOption> pollOptions;
  final int? userVotedOptionId;
  final int totalPollVotes;

  Publication({
    this.id,
    required this.utilisateurId,
    required this.titre,
    required this.contenu,
    required this.type,
    required this.datePublication,
    this.isPinned = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLikedByCurrentUser = false,
    this.isBookmarked = false,
    this.auteurNom,
    this.auteurEmail,
    this.auteurRole,
    this.auteurAvatarSeed,
    this.kudosDestinataireId,
    this.kudosDestinataireNom,
    this.kudosBadge,
    this.formationDate,
    this.formationCompetence,
    this.isUserEnrolled = false,
    this.enrollmentsCount = 0,
    this.pollOptions = const [],
    this.userVotedOptionId,
    this.totalPollVotes = 0,
  });

  /// Calcule un score de tendance (algorithme de popularité)
  int get scoreTendance =>
      (likesCount * 1) + (commentsCount * 2) + (totalPollVotes * 3) + (isPinned ? 100 : 0);

  factory Publication.fromMap(Map<String, dynamic> map, {
    bool isLiked = false,
    bool isEnrolled = false,
    bool isBookmarked = false,
    int commentsCount = 0,
    List<PollOption> pollOptions = const [],
    int? userVotedOptionId,
    int totalPollVotes = 0,
  }) {
    UserRole? role;
    if (map['auteur_role_index'] != null) {
      try {
        role = UserRole.fromIndex(map['auteur_role_index'] as int);
      } catch (_) {}
    }

    return Publication(
      id: map['id'] as int?,
      utilisateurId: map['utilisateur_id'] as int,
      titre: map['titre'] as String,
      contenu: map['contenu'] as String,
      type: map['type'] as String,
      datePublication: map['date_publication'] as String,
      isPinned: (map['is_pinned'] as int?) == 1,
      likesCount: (map['likes_count'] as int?) ?? 0,
      commentsCount: commentsCount,
      isLikedByCurrentUser: isLiked,
      isBookmarked: isBookmarked,
      auteurNom: map['auteur_nom'] as String?,
      auteurEmail: map['auteur_email'] as String?,
      auteurRole: role,
      auteurAvatarSeed: map['auteur_avatar_seed'] as String?,
      kudosDestinataireId: map['kudos_destinataire_id'] as int?,
      kudosDestinataireNom: map['kudos_destinataire_nom'] as String?,
      kudosBadge: map['kudos_badge'] as String?,
      formationDate: map['formation_date'] as String?,
      formationCompetence: map['formation_competence'] as String?,
      isUserEnrolled: isEnrolled,
      enrollmentsCount: (map['enrollments_count'] as int?) ?? 0,
      pollOptions: pollOptions,
      userVotedOptionId: userVotedOptionId,
      totalPollVotes: totalPollVotes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'utilisateur_id': utilisateurId,
      'titre': titre,
      'contenu': contenu,
      'type': type,
      'date_publication': datePublication,
      'is_pinned': isPinned ? 1 : 0,
      'likes_count': likesCount,
      if (kudosDestinataireId != null) 'kudos_destinataire_id': kudosDestinataireId,
      if (kudosDestinataireNom != null) 'kudos_destinataire_nom': kudosDestinataireNom,
      if (kudosBadge != null) 'kudos_badge': kudosBadge,
      if (formationDate != null) 'formation_date': formationDate,
      if (formationCompetence != null) 'formation_competence': formationCompetence,
    };
  }
}
