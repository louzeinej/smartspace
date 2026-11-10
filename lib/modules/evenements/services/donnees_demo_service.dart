import 'dart:math';

import '../entities/utilisateur_courant.dart';
import 'database_service.dart';
import 'participation_service.dart';

// Mettre false à l'intégration pour ne pas créer les données de démo
const bool kCreerDonneesDemo = true;

// Une activité du catalogue de démo
class _ActiviteDemo {
  final String titre;
  final String description;
  final String debut;
  final String fin;
  final int capacite;
  final String categorie;
  // Nombre de personnes déjà inscrites (par des employés fictifs)
  final int inscrits;

  const _ActiviteDemo(
    this.titre,
    this.description,
    this.debut,
    this.fin,
    this.capacite,
    this.categorie,
    this.inscrits,
  );
}

// Outil de démo : crée des activités variées pour tester l'application.
// À utiliser seulement en développement.
class DonneesDemoService {
  // Catalogue des activités possibles
  static const List<_ActiviteDemo> _catalogue = [
    _ActiviteDemo(
      'Atelier danse salsa',
      'Initiation à la salsa, tenue confortable conseillée',
      '08:00',
      '10:00',
      20,
      'Danse',
      8,
    ),
    _ActiviteDemo(
      'Atelier peinture',
      'Peinture acrylique pour débutants, matériel fourni',
      '10:30',
      '12:30',
      12,
      'Peinture',
      12,
    ),
    _ActiviteDemo(
      'Tournoi de padel',
      'Matchs par équipes de 2, niveau débutant accepté',
      '14:00',
      '16:00',
      16,
      'Sport',
      6,
    ),
    _ActiviteDemo(
      'Formation Excel',
      'Formules, tableaux croisés dynamiques et graphiques',
      '09:00',
      '12:00',
      25,
      'Formation',
      10,
    ),
    _ActiviteDemo(
      'Atelier théâtre',
      'Improvisation et expression orale',
      '15:00',
      '17:00',
      15,
      'Autre',
      4,
    ),
    _ActiviteDemo(
      "Chorale de l'équipe",
      "Répétition de chansons pour la fête de fin d'année",
      '17:00',
      '18:30',
      30,
      'Musique',
      22,
    ),
    _ActiviteDemo(
      'Yoga du matin',
      "Séance de relaxation et d'étirements",
      '07:30',
      '08:30',
      10,
      'Sport',
      10,
    ),
    _ActiviteDemo(
      'Atelier cuisine',
      'Préparation d\'un repas partagé entre collègues',
      '12:00',
      '14:00',
      8,
      'Autre',
      3,
    ),
    _ActiviteDemo(
      'Cours de guitare',
      'Découverte de la guitare, instruments prêtés',
      '16:00',
      '17:30',
      6,
      'Musique',
      6,
    ),
    _ActiviteDemo(
      'Hackathon express',
      'Mini-projet en équipes de 3, pizza offerte',
      '09:00',
      '17:00',
      30,
      'Formation',
      15,
    ),
    _ActiviteDemo(
      'Concours de dessin',
      'Thème libre, vote des collègues',
      '11:00',
      '12:30',
      18,
      'Peinture',
      5,
    ),
    _ActiviteDemo(
      'Atelier photo',
      'Techniques de cadrage avec son téléphone',
      '14:30',
      '16:00',
      14,
      'Autre',
      7,
    ),
  ];

  // Employés fictifs (jamais l'id 1)
  static const List<int> _utilisateursDemo = [11, 12, 13];

  // Nombre d'activités ajoutées pour chaque événement
  static const int _activitesParEvenement = 4;

  // Répartit "total" personnes sur 1 à 3 participations (la somme est exacte)
  static List<int> _repartir(int total) {
    if (total <= 0) return [];
    final nbParts = total >= 9 ? 3 : (total >= 4 ? 2 : 1);
    final base = total ~/ nbParts;
    final reste = total % nbParts;
    // Les premières parts reçoivent une personne de plus s'il reste un reliquat
    return List.generate(nbParts, (i) => base + (i < reste ? 1 : 0));
  }

  // Ajoute les activités de démo et renvoie le nombre d'activités ajoutées
  Future<int> insererDonneesDemo() async {
    final db = await DatabaseService.instance.database;
    var ajoutees = 0;

    // Tout se fait dans une seule transaction : tout est enregistré, ou rien
    await db.transaction((txn) async {
      final evenements = await txn.query('evenements', orderBy: 'id ASC');
      final maintenant = DateTime.now().toIso8601String();
      final batch = txn.batch();
      // Compte les événements traités, pour varier le catalogue
      var rang = 0;

      for (final evenement in evenements) {
        final evenementId = evenement['id'] as int;

        // On saute les événements qui ont déjà des activités
        final existantes = await txn.query(
          'activites',
          columns: ['id'],
          where: 'evenement_id = ?',
          whereArgs: [evenementId],
          limit: 1,
        );
        if (existantes.isNotEmpty) continue;

        for (var k = 0; k < _activitesParEvenement; k++) {
          // On tourne dans le catalogue d'un événement à l'autre
          final modele =
              _catalogue[(rang * _activitesParEvenement + k) %
                  _catalogue.length];

          final activiteId = await txn.insert('activites', {
            'evenement_id': evenementId,
            'titre': modele.titre,
            'description': modele.description,
            'heure_debut': modele.debut,
            'heure_fin': modele.fin,
            'capacite_max': modele.capacite,
            'categorie': modele.categorie,
          });
          ajoutees++;

          // Participations de démo : le total ne dépasse jamais la capacité
          final total = modele.inscrits > modele.capacite
              ? modele.capacite
              : modele.inscrits;
          final parts = _repartir(total);
          for (var i = 0; i < parts.length; i++) {
            batch.insert('participations', {
              'activite_id': activiteId,
              'utilisateur_id': _utilisateursDemo[i],
              'date_inscription': maintenant,
              'nombre_personnes': parts[i],
            });
          }
        }
        rang++;
      }

      await batch.commit(noResult: true);
    });

    return ajoutees;
  }

  // Inscrit un employé à plusieurs activités (jusqu'à "maximum")
  // et renvoie le nombre d'inscriptions créées
  Future<int> inscrireUtilisateurAuxActivites(
    int utilisateurId, {
    int maximum = 10,
  }) async {
    final db = await DatabaseService.instance.database;
    final hasard = Random();
    var creees = 0;

    // Tout se fait dans une seule transaction
    await db.transaction((txn) async {
      // Toutes les activités avec la date de leur événement,
      // et l'info "cet employé est-il déjà inscrit ?"
      final lignes = await txn.rawQuery(
        '''
        SELECT a.id, a.heure_debut, a.heure_fin, a.capacite_max, e.date,
          (SELECT COUNT(*) FROM participations p
            WHERE p.activite_id = a.id AND p.utilisateur_id = ?) AS deja
        FROM activites a
        JOIN evenements e ON e.id = a.evenement_id
      ''',
        [utilisateurId],
      );

      // Créneaux où l'employé participe déjà (date, début, fin)
      final creneaux = (await txn.rawQuery(
        '''
        SELECT e.date, a.heure_debut, a.heure_fin
        FROM participations p
        JOIN activites a ON a.id = p.activite_id
        JOIN evenements e ON e.id = a.evenement_id
        WHERE p.utilisateur_id = ?
      ''',
        [utilisateurId],
      )).toList();

      final maintenant = DateTime.now();
      // On garde seulement les activités pas terminées et pas déjà choisies
      final candidates = lignes.where((ligne) {
        if ((ligne['deja'] as int) > 0) return false;
        final fin = DateTime.tryParse('${ligne['date']} ${ligne['heure_fin']}');
        return fin != null && fin.isAfter(maintenant);
      }).toList();

      // On mélange pour varier les événements
      candidates.shuffle(hasard);

      // Date du jour au format AAAA-MM-JJ
      final mois = maintenant.month.toString().padLeft(2, '0');
      final jour = maintenant.day.toString().padLeft(2, '0');
      final dateDuJour = '${maintenant.year}-$mois-$jour';

      for (final ligne in candidates) {
        if (creees >= maximum) break;
        final activiteId = ligne['id'] as int;
        final capacite = ligne['capacite_max'] as int;

        // On saute l'activité si elle chevauche une activité déjà choisie
        final enConflit = creneaux.any(
          (creneau) =>
              creneau['date'] == ligne['date'] &&
              ParticipationService.chevauche(
                ligne['heure_debut'] as String,
                ligne['heure_fin'] as String,
                creneau['heure_debut'] as String,
                creneau['heure_fin'] as String,
              ),
        );
        if (enConflit) continue;

        // On recalcule les places restantes juste avant d'inscrire
        final somme = await txn.rawQuery(
          'SELECT COALESCE(SUM(nombre_personnes), 0) AS total '
          'FROM participations WHERE activite_id = ?',
          [activiteId],
        );
        final restantes = capacite - (somme.first['total'] as int);
        if (restantes < 1) continue;

        // 2 personnes une fois sur trois (si assez de places), sinon 1
        final personnes = (restantes >= 2 && hasard.nextInt(3) == 0) ? 2 : 1;

        await txn.insert('participations', {
          'activite_id': activiteId,
          'utilisateur_id': utilisateurId,
          'date_inscription': dateDuJour,
          'nombre_personnes': personnes,
        });
        creees++;
        // Ce créneau est maintenant pris
        creneaux.add(ligne);
      }
    });

    return creees;
  }

  // Titre de l'événement de démonstration
  static const String _titreDemo = 'Journée Clubs & Ateliers';

  // Anciens événements de démo : supprimés pour ne pas laisser de doublons
  static const List<String> _anciensTitresDemo = [
    "Journée d'intégration 2026",
    'Journée du club',
    'Tournoi sportif interne',
    'Semaine des clubs',
  ];

  // Date au format AAAA-MM-JJ (avec les zéros)
  static String _formaterDate(DateTime date) {
    final mois = date.month.toString().padLeft(2, '0');
    final jour = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mois-$jour';
  }

  // Heure HH:MM à partir d'un nombre de minutes depuis minuit
  // (bornée entre 00:00 et 23:59 si ça déborde)
  static String _formaterHeure(int minutes) {
    final borne = minutes.clamp(0, 23 * 60 + 59).toInt();
    final heures = (borne ~/ 60).toString().padLeft(2, '0');
    final reste = (borne % 60).toString().padLeft(2, '0');
    return '$heures:$reste';
  }

  // Crée l'événement de démonstration "Journée Clubs & Ateliers" :
  // un seul événement qui montre toutes les règles métier.
  // On écrit directement dans les tables : les inscriptions à une activité
  // terminée seraient refusées par ParticipationService.
  Future<String> creerJeuDeTest() async {
    final db = await DatabaseService.instance.database;
    // "Moi" = l'employé courant au moment du clic
    final moi = UtilisateurCourant.id;
    final maintenant = DateTime.now();
    final dateDuJour = _formaterDate(maintenant);

    // t = l'heure actuelle arrondie à la demi-heure inférieure (en minutes)
    final t = (maintenant.hour * 60 + maintenant.minute) ~/ 30 * 30;
    // Raccourci : "h(1.5)" = 1 h 30 min
    int h(double heures) => (heures * 60).round();

    var dejaCree = false;
    var nbActivites = 0;
    var nbParticipations = 0;

    // Tout se fait dans une seule transaction : tout est créé, ou rien
    await db.transaction((txn) async {
      // Nettoyage : anciens événements "TEST –" et anciennes démos
      await txn.delete(
        'evenements',
        where: 'titre LIKE ? OR titre IN (?, ?, ?, ?)',
        whereArgs: ['TEST –%', ..._anciensTitresDemo],
      );

      // Si la démo du jour existe déjà, on ne crée rien.
      // Si elle date d'un autre jour, on la supprime pour la recréer.
      final existants = await txn.query(
        'evenements',
        columns: ['id', 'date'],
        where: 'titre = ?',
        whereArgs: [_titreDemo],
      );
      if (existants.any((ligne) => ligne['date'] == dateDuJour)) {
        dejaCree = true;
        return;
      }
      await txn.delete(
        'evenements',
        where: 'titre = ?',
        whereArgs: [_titreDemo],
      );

      // L'événement (id récupéré avec le retour de insert)
      final evenementId = await txn.insert('evenements', {
        'titre': _titreDemo,
        'description':
            "Une journée d'activités, de clubs et d'ateliers pour toute l'équipe",
        'date': dateDuJour,
        'lieu': 'Tunis',
        'image': 'fete.jpg',
      });

      // Ajoute une activité et ses participations
      // debut et fin = minutes depuis minuit ; capacite = maximum
      // participants = liste de (id de l'employé, nombre de personnes)
      Future<void> activite(
        String titre,
        int debut,
        int fin,
        int capacite,
        int minimum,
        String categorie,
        List<(int, int)> participants,
      ) async {
        final activiteId = await txn.insert('activites', {
          'evenement_id': evenementId,
          'titre': titre,
          'description': 'Activité proposée aux employés',
          'heure_debut': _formaterHeure(debut),
          'heure_fin': _formaterHeure(fin),
          'capacite_max': capacite,
          'capacite_min': minimum,
          'categorie': categorie,
        });
        nbActivites++;

        // Un seul employé par couple (activité, employé) : si "moi" est
        // aussi un employé fictif, on additionne ses personnes
        final parEmploye = <int, int>{};
        for (final (employe, personnes) in participants) {
          parEmploye.update(employe, (n) => n + personnes,
              ifAbsent: () => personnes);
        }
        for (final entree in parEmploye.entries) {
          await txn.insert('participations', {
            'activite_id': activiteId,
            'utilisateur_id': entree.key,
            'date_inscription': dateDuJour,
            'nombre_personnes': entree.value,
          });
          nbParticipations++;
        }
      }

      // Terminée
      await activite('Atelier yoga', t - h(3), t - h(2), 10, 0, 'Sport',
          [(moi, 2), (11, 3)]);
      // Annulée (2 personnes pour un minimum de 5)
      await activite('Conférence bien-être', t - h(2), t - h(1), 20, 5,
          'Formation', [(moi, 1), (11, 1)]);
      // En cours (je ne participe pas)
      await activite('Atelier créativité', t - h(0.5), t + h(1.5), 10, 0,
          'Autre', [(12, 3)]);
      // Presque complète (8/10)
      await activite('Tournoi de padel', t + h(2), t + h(3), 10, 0, 'Sport',
          [(11, 4), (12, 4)]);
      // Complète (6/6)
      await activite('Atelier cuisine', t + h(3), t + h(4), 6, 0, 'Autre',
          [(11, 3), (12, 3)]);
      // Ouverte (4/20)
      await activite('Séance de méditation', t + h(4), t + h(5), 20, 0,
          'Autre', [(13, 4)]);
      // Minimum non atteint (il en manque 2)
      await activite('Randonnée', t + h(2), t + h(3), 20, 5, 'Sport',
          [(11, 2), (12, 1)]);
      // Minimum atteint
      await activite('Club lecture', t + h(2), t + h(3), 20, 3, 'Autre',
          [(11, 2), (12, 2)]);
      // Conflit d'horaires : la danse et la peinture se chevauchent
      await activite('Atelier danse', t + h(5), t + h(6.5), 15, 0, 'Autre',
          [(moi, 1)]);
      await activite(
          'Atelier peinture', t + h(5.5), t + h(7), 12, 0, 'Autre', []);
      // Pas de conflit : ce cours commence quand la danse se termine
      await activite(
          'Cours de chant', t + h(6.5), t + h(7.5), 20, 0, 'Autre', []);
    });

    if (dejaCree) return 'La démo existe déjà';
    return '1 événement, $nbActivites activités, '
        '$nbParticipations participations créés';
  }

  // Supprime la démo ("Journée Clubs & Ateliers"), les anciennes démos
  // et les anciens "TEST –". Leurs activités et participations partent
  // avec eux.
  Future<String> supprimerJeuDeTest() async {
    final db = await DatabaseService.instance.database;

    // La suppression en cascade demande que les clés étrangères soient actives
    final reglage = await db.rawQuery('PRAGMA foreign_keys');
    if (reglage.first.values.first != 1) {
      await db.execute('PRAGMA foreign_keys = ON');
    }

    final supprimes = await db.delete(
      'evenements',
      where: 'titre LIKE ? OR titre IN (?, ?, ?, ?, ?)',
      whereArgs: ['TEST –%', _titreDemo, ..._anciensTitresDemo],
    );
    return '$supprimes événement(s) de démo supprimé(s)';
  }
}
