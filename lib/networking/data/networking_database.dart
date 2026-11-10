import 'package:sqflite/sqflite.dart';

/// Gestion SQLite du module Networking (Réseau social interne / Mini-LinkedIn).
class NetworkingDatabase {
  NetworkingDatabase._();

  static Future<void> createTables(DatabaseExecutor db) async {
    // 1. Table principale des publications
    await db.execute('''
      CREATE TABLE IF NOT EXISTS publications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        utilisateur_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        titre TEXT NOT NULL,
        contenu TEXT NOT NULL,
        type TEXT NOT NULL,
        date_publication TEXT NOT NULL,
        is_pinned INTEGER DEFAULT 0,
        likes_count INTEGER DEFAULT 0,
        kudos_destinataire_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
        kudos_destinataire_nom TEXT,
        kudos_badge TEXT,
        formation_date TEXT,
        formation_competence TEXT
      )
    ''');

    // 2. Table des likes/mentions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS publication_likes (
        publication_id INTEGER NOT NULL REFERENCES publications(id) ON DELETE CASCADE,
        utilisateur_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        PRIMARY KEY (publication_id, utilisateur_id)
      )
    ''');

    // 3. Table des commentaires
    await db.execute('''
      CREATE TABLE IF NOT EXISTS publication_comments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        publication_id INTEGER NOT NULL REFERENCES publications(id) ON DELETE CASCADE,
        utilisateur_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        commentaire TEXT NOT NULL,
        date_commentaire TEXT NOT NULL
      )
    ''');

    // 4. Tables pour les sondages
    await db.execute('''
      CREATE TABLE IF NOT EXISTS poll_options (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        publication_id INTEGER NOT NULL REFERENCES publications(id) ON DELETE CASCADE,
        option_texte TEXT NOT NULL,
        votes_count INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS poll_votes (
        publication_id INTEGER NOT NULL REFERENCES publications(id) ON DELETE CASCADE,
        option_id INTEGER NOT NULL REFERENCES poll_options(id) ON DELETE CASCADE,
        utilisateur_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        PRIMARY KEY (publication_id, utilisateur_id)
      )
    ''');

    // 5. Table pour les inscriptions aux formations
    await db.execute('''
      CREATE TABLE IF NOT EXISTS training_enrollments (
        publication_id INTEGER NOT NULL REFERENCES publications(id) ON DELETE CASCADE,
        utilisateur_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        date_inscription TEXT NOT NULL,
        PRIMARY KEY (publication_id, utilisateur_id)
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_pub_type ON publications(type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pub_pinned ON publications(is_pinned)');
  }

  /// Insère des données de démonstration variées au premier démarrage
  static Future<void> seedDemoPublicationsIfEmpty(Database db) async {
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM publications'),
        ) ??
        0;
    if (count > 0) return;

    // Récupérer les ID des utilisateurs de démo
    final adminUser = await db.query('users', where: "email = 'admin@smartspace.tn'", limit: 1);
    final uiuxUser = await db.query('users', where: "email = 'uiux@smartspace.tn'", limit: 1);
    final hrUser = await db.query('users', where: "email = 'louzeine@smartspace.tn'", limit: 1);
    final scrumUser = await db.query('users', where: "email = 'scrum@smartspace.tn'", limit: 1);

    final adminId = adminUser.isNotEmpty ? adminUser.first['id'] as int : 1;
    final uiuxId = uiuxUser.isNotEmpty ? uiuxUser.first['id'] as int : 4;
    final hrId = hrUser.isNotEmpty ? hrUser.first['id'] as int : 5;
    final scrumId = scrumUser.isNotEmpty ? scrumUser.first['id'] as int : 2;

    final now = DateTime.now();

    // 1. Annonce officielle épinglée
    final pub1Id = await db.insert('publications', {
      'utilisateur_id': adminId,
      'titre': '🚀 Lancement Officiel de SmartSpace !',
      'contenu':
          'Bienvenue à toutes et à tous sur notre réseau interne SmartSpace. Profitez de cet espace pour échanger vos actualités, proposer des formations et féliciter vos collègues !',
      'type': 'Annonce',
      'date_publication': now.subtract(const Duration(hours: 5)).toIso8601String(),
      'is_pinned': 1,
      'likes_count': 4,
    });

    // Likes sur pub1
    await db.insert('publication_likes', {'publication_id': pub1Id, 'utilisateur_id': uiuxId});
    await db.insert('publication_likes', {'publication_id': pub1Id, 'utilisateur_id': hrId});

    // 2. Kudos de félicitation
    await db.insert('publications', {
      'utilisateur_id': scrumId,
      'titre': 'Bravo à Manar pour la nouvelle charte UI/UX ! 🎨',
      'contenu':
          'Un grand merci à Manar Kalai pour les superbes maquettes du module Networking et le respect de la charte violette !',
      'type': 'Kudos',
      'date_publication': now.subtract(const Duration(hours: 3)).toIso8601String(),
      'is_pinned': 0,
      'likes_count': 3,
      'kudos_destinataire_id': uiuxId,
      'kudos_destinataire_nom': 'Manar Kalai',
      'kudos_badge': '🎨 Excellence UI/UX',
    });

    // 3. Offre de Formation RH
    final pub3Id = await db.insert('publications', {
      'utilisateur_id': hrId,
      'titre': 'Atelier Pratique : Jetpack Compose & Flutter State Management',
      'contenu':
          'Le pôle RH organise un atelier de perfectionnement technique vendredi prochain de 14h à 16h. Inscrivez-vous vite ci-dessous !',
      'type': 'Formation',
      'date_publication': now.subtract(const Duration(hours: 2)).toIso8601String(),
      'is_pinned': 0,
      'likes_count': 2,
      'formation_date': 'Vendredi 14:00 - 16:00',
      'formation_competence': 'Flutter & Clean Architecture',
    });

    // Inscription démo
    await db.insert('training_enrollments', {
      'publication_id': pub3Id,
      'utilisateur_id': uiuxId,
      'date_inscription': now.subtract(const Duration(hours: 1)).toIso8601String(),
    });

    // 4. Sondage Interactif
    final pub4Id = await db.insert('publications', {
      'utilisateur_id': uiuxId,
      'titre': 'Sondage : Destination pour la sortie d\'équipe du trimestre',
      'contenu': 'Donnez votre avis pour la prochaine sortie collective de l\'entreprise !',
      'type': 'Sondage',
      'date_publication': now.subtract(const Duration(minutes: 30)).toIso8601String(),
      'is_pinned': 0,
      'likes_count': 1,
    });

    // Options du sondage
    final opt1 = await db.insert('poll_options', {
      'publication_id': pub4Id,
      'option_texte': '🏞️ Randonnée & Pique-nique en montagne',
      'votes_count': 2,
    });
    final opt2 = await db.insert('poll_options', {
      'publication_id': pub4Id,
      'option_texte': '🏎️ Karting & Laser Tag',
      'votes_count': 1,
    });
    await db.insert('poll_options', {
      'publication_id': pub4Id,
      'option_texte': '🎨 Atelier Poterie & Peinture',
      'votes_count': 0,
    });

    // Votes démo
    await db.insert('poll_votes', {
      'publication_id': pub4Id,
      'option_id': opt1,
      'utilisateur_id': adminId,
    });
    await db.insert('poll_votes', {
      'publication_id': pub4Id,
      'option_id': opt1,
      'utilisateur_id': hrId,
    });
    await db.insert('poll_votes', {
      'publication_id': pub4Id,
      'option_id': opt2,
      'utilisateur_id': scrumId,
    });
  }
}
