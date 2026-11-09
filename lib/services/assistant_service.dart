import '../database/user_dao.dart';
import '../models/user_role.dart';

/// Assistant intelligent intégré (VALEUR AJOUTÉE).
///
/// Analyse la question en langage naturel (mots-clés + extraction de
/// paramètres) et répond en s'appuyant sur les DONNÉES RÉELLES de la
/// base SQLite : recherche d'utilisateurs, statistiques par rôle,
/// rôles des membres, aide sur les fonctionnalités (mot de passe
/// oublié, avatars DiceBear, etc.).
///
/// 100 % offline : aucune donnée ne quitte l'appareil — argument à
/// mettre en avant en soutenance.
class AssistantService {
  AssistantService._();
  static final AssistantService instance = AssistantService._();

  final UserDao _dao = UserDao.instance;

  /// Traite un message utilisateur et retourne la réponse de
  /// l'assistant. [userName] sert à personnaliser la salutation.
  Future<String> respond(String message, {String? userName}) async {
    final msg = message.toLowerCase().trim();

    // ── Salutations ──
    if (RegExp(r'^(bonjour|salut|hello|hey|bonsoir|slt)\b').hasMatch(msg)) {
      final name = (userName ?? '').split(' ').first;
      return 'Bonjour ${name.isEmpty ? '' : '$name ! 👋'} '
          'Je suis l\'assistant SmartSpace. Demande-moi par exemple :\n'
          '• « cherche Manar »\n'
          '• « combien de développeurs ? »\n'
          '• « qui est administrateur ? »\n'
          '• « j\'ai oublié mon mot de passe »';
    }

    // ── Mot de passe oublié ──
    if (_has(msg, ['mot de passe', 'mdp', 'password']) &&
        _has(msg, ['oubli', 'perdu', 'oublie', 'reset', 'réinitialis'])) {
      return '🔒 Pas de panique : sur l\'écran de connexion, touche '
          '« Mot de passe oublié ? ». Tu devras répondre à la question '
          'secrète choisie à ton inscription, puis définir un nouveau '
          'mot de passe. (L\'application étant hors-ligne, tout se '
          'vérifie localement via un hash SHA-256.)';
    }

    // ── Recherche d'un utilisateur ──
    final searchMatch = RegExp(
      r'(cherche|trouve|recherche|ou est|où est)\s+(?:le|la|les|un|une)?\s*(.+)'
    ).firstMatch(msg);
    if (searchMatch != null) {
      var term = searchMatch.group(2)!;
      // retire les mots parasites en fin de question
      term = term
          .replaceAll(RegExp(r"\s*(s'il vous plaît|svp|stp)\s*$"), '')
          .replaceAll(RegExp(r'\?+\s*$'), '')
          .trim();
      if (term.isNotEmpty) {
        final results = await _dao.search(term);
        if (results.isEmpty) {
          return 'Aucun utilisateur ne correspond à « $term ». 😕';
        }
        return '🔎 ${results.length} résultat(s) pour « $term » :\n\n'
            '${results.map((u) => '• ${u.fullName} — ${u.role.label} (${u.email})').join('\n')}';
      }
    }

    // ── Statistiques par rôle ──
    if (_has(msg, ['combien', 'nombre', 'statistique', 'effectif', 'équipe',
          'equipe'])) {
      // Détecte un rôle précis dans la question, sinon stats globales.
      final role = UserRole.values.where((r) =>
          msg.contains(r.label.toLowerCase()) ||
          (r == UserRole.developpeur && msg.contains('developpeur')) ||
          (r == UserRole.uiuxDesigner &&
              (msg.contains('designer') || msg.contains('ui'))));
      if (role.isNotEmpty) {
        final all = await _dao.getAll();
        final n = all.where((u) => u.role == role.first).length;
        return '👥 Il y a actuellement $n ${role.first.label}'
            '${n > 1 ? 's' : ''} dans l\'équipe.';
      }
      final counts = await _dao.countByRole();
      final total = counts.values.fold<int>(0, (a, b) => a + b);
      if (total == 0) return 'Il n\'y a encore aucun utilisateur. 📭';
      final lines = counts.entries.map((e) {
        final r = UserRole.fromIndex(e.key);
        return '• ${r.label} : ${e.value}';
      }).join('\n');
      return '📊 Répartition des $total membres de l\'équipe :\n$lines';
    }

    // ── Qui est administrateur ? ──
    if (_has(msg, ['administrateur', 'admin']) &&
        _has(msg, ['qui', 'quel'])) {
      final admins =
          (await _dao.getAll()).where((u) => u.role == UserRole.administrateur);
      final names = admins.map((u) => u.fullName).join(', ');
      return names.isEmpty
          ? 'Aucun administrateur n\'est défini.'
          : '👑 Administrateur(s) : $names. Seul un administrateur peut '
              'supprimer un compte ou changer les rôles.';
    }

    // ── Rôles disponibles ──
    if (_has(msg, ['rôle', 'role']) && _has(msg, ['liste', 'disponible',
          'existe', 'quels', 'quelles'])) {
      return '🏷️ Rôles disponibles dans SmartSpace :\n'
          '${UserRole.values.map((r) => '• ${r.label}').join('\n')}\n\n'
          'Le rôle détermine les tâches qui peuvent être confiées '
          'à un membre (module Projets & Tâches).';
    }

    // ── Avatars / DiceBear ──
    if (_has(msg, ['avatar', 'photo', 'dicebear', 'image'])) {
      return '🖼️ Chaque membre reçoit un avatar généré par le web service '
          'DiceBear (valeur ajoutée du module). Hors-ligne, ses initiales '
          'sont affichées à la place — l\'application reste utilisable '
          'sans connexion.';
    }

    // ── Aide ──
    if (_has(msg, ['aide', 'help', 'que peux', 'comment', 'fonctionne'])) {
      return 'ℹ️ Je peux t\'aider sur :\n'
          '• Rechercher un membre : « cherche Youssef »\n'
          '• Statistiques : « combien de développeurs ? »\n'
          '• Voir l\'admin : « qui est administrateur ? »\n'
          '• Mot de passe oublié\n'
          '• Rôles et avatars';
    }

    // ── Fallback ──
    return 'Je n\'ai pas compris « $message ». 🤔 Tape « aide » pour voir '
        'ce que je sais faire.';
  }

  bool _has(String text, List<String> keys) =>
      keys.any((k) => text.contains(k));
}
