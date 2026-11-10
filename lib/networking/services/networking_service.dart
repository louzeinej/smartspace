import 'package:sqflite/sqflite.dart';
import '../../core/database_helper.dart';
import '../models/publication.dart';

/// Service gérant toute la logique métier et les requêtes SQL du module Networking.
class NetworkingService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Récupère la liste enrichie des publications avec filtres, recherche et tri
  Future<List<Publication>> getPublications({
    String? filterType,
    String? searchQuery,
    String sortBy = 'recent', // 'recent' ou 'tendance'
    int? currentUserId,
  }) async {
    final db = await _dbHelper.database;

    String whereClause = '1=1';
    final List<dynamic> whereArgs = [];

    // Filtre par type de publication
    if (filterType != null && filterType.isNotEmpty && filterType != 'Tout') {
      if (filterType.contains('Annonce')) {
        whereClause += ' AND (p.type = ? OR p.is_pinned = 1)';
        whereArgs.add(PublicationType.annonce);
      } else if (filterType.contains('Actualité')) {
        whereClause += ' AND p.type = ?';
        whereArgs.add(PublicationType.actualite);
      } else if (filterType.contains('Formation')) {
        whereClause += ' AND p.type = ?';
        whereArgs.add(PublicationType.formation);
      } else if (filterType.contains('Sondage')) {
        whereClause += ' AND p.type = ?';
        whereArgs.add(PublicationType.sondage);
      } else if (filterType.contains('Kudos')) {
        whereClause += ' AND p.type = ?';
        whereArgs.add(PublicationType.kudos);
      }
    }

    // Filtre par recherche textuelle
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final query = '%${searchQuery.trim()}%';
      whereClause +=
          ' AND (p.titre LIKE ? OR p.contenu LIKE ? OR u.fullName LIKE ? OR p.formation_competence LIKE ?)';
      whereArgs.addAll([query, query, query, query]);
    }

    final sql = '''
      SELECT
        p.*,
        u.fullName AS auteur_nom,
        u.email AS auteur_email,
        u.roleIndex AS auteur_role_index,
        u.avatarSeed AS auteur_avatar_seed,
        (SELECT COUNT(*) FROM training_enrollments te WHERE te.publication_id = p.id) AS enrollments_count
      FROM publications p
      INNER JOIN users u ON p.utilisateur_id = u.id
      WHERE $whereClause
      ORDER BY p.is_pinned DESC, p.date_publication DESC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(sql, whereArgs);
    final List<Publication> result = [];

    for (final map in maps) {
      final pubId = map['id'] as int;

      // 1. Vérifier si liké par l'utilisateur courant
      bool isLiked = false;
      if (currentUserId != null) {
        final likeRes = await db.query(
          'publication_likes',
          where: 'publication_id = ? AND utilisateur_id = ?',
          whereArgs: [pubId, currentUserId],
        );
        isLiked = likeRes.isNotEmpty;
      }

      // 2. Compter les commentaires
      final commentCountRes = Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM publication_comments WHERE publication_id = ?',
              [pubId],
            ),
          ) ??
          0;

      // 3. Traiter les données de sondage si type = Sondage
      List<PollOption> pollOptions = [];
      int? userVotedOptionId;
      int totalPollVotes = 0;

      if (map['type'] == PublicationType.sondage) {
        final optionsMaps = await db.query(
          'poll_options',
          where: 'publication_id = ?',
          whereArgs: [pubId],
        );
        pollOptions = optionsMaps.map((m) => PollOption.fromMap(m)).toList();

        totalPollVotes = pollOptions.fold<int>(0, (sum, opt) => sum + opt.votesCount);

        if (currentUserId != null) {
          final voteRes = await db.query(
            'poll_votes',
            where: 'publication_id = ? AND utilisateur_id = ?',
            whereArgs: [pubId, currentUserId],
            limit: 1,
          );
          if (voteRes.isNotEmpty) {
            userVotedOptionId = voteRes.first['option_id'] as int;
          }
        }
      }

      // 4. Traiter l'inscription formation si type = Formation
      bool isEnrolled = false;
      if (map['type'] == PublicationType.formation && currentUserId != null) {
        final enrollRes = await db.query(
          'training_enrollments',
          where: 'publication_id = ? AND utilisateur_id = ?',
          whereArgs: [pubId, currentUserId],
        );
        isEnrolled = enrollRes.isNotEmpty;
      }

      final pub = Publication.fromMap(
        map,
        isLiked: isLiked,
        isEnrolled: isEnrolled,
        commentsCount: commentCountRes,
        pollOptions: pollOptions,
        userVotedOptionId: userVotedOptionId,
        totalPollVotes: totalPollVotes,
      );

      result.add(pub);
    }

    // Tri par score de tendance si demandé
    if (sortBy == 'tendance') {
      result.sort((a, b) => b.scoreTendance.compareTo(a.scoreTendance));
    }

    return result;
  }

  /// Créer une nouvelle publication (avec options de sondage facultatives)
  Future<int> createPublication(Publication pub, {List<String>? pollOptions}) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final pubId = await txn.insert('publications', pub.toMap());

      if (pub.type == PublicationType.sondage && pollOptions != null) {
        for (final text in pollOptions) {
          if (text.trim().isNotEmpty) {
            await txn.insert('poll_options', {
              'publication_id': pubId,
              'option_texte': text.trim(),
              'votes_count': 0,
            });
          }
        }
      }
      return pubId;
    });
  }

  /// Mettre à jour / Éditer une publication existante
  Future<void> updatePublication(Publication pub, {List<String>? pollOptions}) async {
    if (pub.id == null) return;
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'publications',
        pub.toMap(),
        where: 'id = ?',
        whereArgs: [pub.id],
      );

      if (pub.type == PublicationType.sondage && pollOptions != null && pollOptions.isNotEmpty) {
        // Mettre à jour les options de sondage
        await txn.delete('poll_options', where: 'publication_id = ?', whereArgs: [pub.id]);
        for (final text in pollOptions) {
          if (text.trim().isNotEmpty) {
            await txn.insert('poll_options', {
              'publication_id': pub.id,
              'option_texte': text.trim(),
              'votes_count': 0,
            });
          }
        }
      }
    });
  }

  /// Supprimer une publication
  Future<void> deletePublication(int pubId) async {
    final db = await _dbHelper.database;
    await db.delete('publications', where: 'id = ?', whereArgs: [pubId]);
  }

  /// Épingler / Désépingler une publication (Admin)
  Future<void> togglePin(int pubId, bool currentPinState) async {
    final db = await _dbHelper.database;
    await db.update(
      'publications',
      {'is_pinned': currentPinState ? 0 : 1},
      where: 'id = ?',
      whereArgs: [pubId],
    );
  }

  /// Toggle Like
  Future<bool> toggleLike(int pubId, int userId) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final existing = await txn.query(
        'publication_likes',
        where: 'publication_id = ? AND utilisateur_id = ?',
        whereArgs: [pubId, userId],
      );

      if (existing.isNotEmpty) {
        // Un-like
        await txn.delete(
          'publication_likes',
          where: 'publication_id = ? AND utilisateur_id = ?',
          whereArgs: [pubId, userId],
        );
        await txn.rawUpdate(
          'UPDATE publications SET likes_count = MAX(0, likes_count - 1) WHERE id = ?',
          [pubId],
        );
        return false;
      } else {
        // Like
        await txn.insert('publication_likes', {
          'publication_id': pubId,
          'utilisateur_id': userId,
        });
        await txn.rawUpdate(
          'UPDATE publications SET likes_count = likes_count + 1 WHERE id = ?',
          [pubId],
        );
        return true;
      }
    });
  }

  /// Vote dans un sondage
  Future<void> votePollOption(int pubId, int optionId, int userId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final existingVote = await txn.query(
        'poll_votes',
        where: 'publication_id = ? AND utilisateur_id = ?',
        whereArgs: [pubId, userId],
      );

      if (existingVote.isNotEmpty) {
        final prevOptionId = existingVote.first['option_id'] as int;
        if (prevOptionId == optionId) return; // Déjà voté pour cette option

        // Décrémenter l'ancienne option
        await txn.rawUpdate(
          'UPDATE poll_options SET votes_count = MAX(0, votes_count - 1) WHERE id = ?',
          [prevOptionId],
        );
        // Mettre à jour le vote
        await txn.update(
          'poll_votes',
          {'option_id': optionId},
          where: 'publication_id = ? AND utilisateur_id = ?',
          whereArgs: [pubId, userId],
        );
      } else {
        // Nouveau vote
        await txn.insert('poll_votes', {
          'publication_id': pubId,
          'option_id': optionId,
          'utilisateur_id': userId,
        });
      }

      // Incrémenter la nouvelle option
      await txn.rawUpdate(
        'UPDATE poll_options SET votes_count = votes_count + 1 WHERE id = ?',
        [optionId],
      );
    });
  }

  /// Inscription / Désinscription à une formation
  Future<bool> toggleTrainingEnrollment(int pubId, int userId) async {
    final db = await _dbHelper.database;
    final existing = await db.query(
      'training_enrollments',
      where: 'publication_id = ? AND utilisateur_id = ?',
      whereArgs: [pubId, userId],
    );

    if (existing.isNotEmpty) {
      await db.delete(
        'training_enrollments',
        where: 'publication_id = ? AND utilisateur_id = ?',
        whereArgs: [pubId, userId],
      );
      return false;
    } else {
      await db.insert('training_enrollments', {
        'publication_id': pubId,
        'utilisateur_id': userId,
        'date_inscription': DateTime.now().toIso8601String(),
      });
      return true;
    }
  }

  /// Récupère la liste des inscrits à une formation (pour RH/Admin)
  Future<List<Map<String, dynamic>>> getTrainingParticipants(int pubId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT u.id, u.fullName AS nom, u.email, u.roleIndex, u.avatarSeed AS avatar_seed, te.date_inscription
      FROM training_enrollments te
      INNER JOIN users u ON te.utilisateur_id = u.id
      WHERE te.publication_id = ?
      ORDER BY te.date_inscription ASC
    ''', [pubId]);
  }

  /// Récupère les commentaires d'une publication
  Future<List<PublicationComment>> getComments(int pubId) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT
        c.*,
        u.fullName AS auteur_nom,
        u.email AS auteur_email,
        u.roleIndex AS auteur_role_index,
        u.avatarSeed AS auteur_avatar_seed
      FROM publication_comments c
      INNER JOIN users u ON c.utilisateur_id = u.id
      WHERE c.publication_id = ?
      ORDER BY c.date_commentaire ASC
    ''', [pubId]);

    return maps.map((m) => PublicationComment.fromMap(m)).toList();
  }

  /// Ajouter un commentaire
  Future<void> addComment(int pubId, int userId, String text) async {
    final db = await _dbHelper.database;
    await db.insert('publication_comments', {
      'publication_id': pubId,
      'utilisateur_id': userId,
      'commentaire': text.trim(),
      'date_commentaire': DateTime.now().toIso8601String(),
    });
  }

  /// Supprimer un commentaire
  Future<void> deleteComment(int commentId) async {
    final db = await _dbHelper.database;
    await db.delete('publication_comments', where: 'id = ?', whereArgs: [commentId]);
  }

  /// Récupère la liste de tous les utilisateurs pour le sélecteur de Kudos
  Future<List<Map<String, dynamic>>> getAllUsersForKudos() async {
    final db = await _dbHelper.database;
    return await db.query('users', columns: ['id', 'fullName', 'email', 'roleIndex', 'avatarSeed'], orderBy: 'fullName ASC');
  }
}
