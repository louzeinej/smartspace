import 'dart:math';

import 'database_service.dart';
import 'participation_service.dart';

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
}
