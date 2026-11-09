import 'package:flutter_test/flutter_test.dart';
import 'package:smartspace/database/user_database.dart';
import 'package:smartspace/models/user_model.dart';
import 'package:smartspace/models/user_role.dart';
import 'package:smartspace/projets/data/projet_database.dart';
import 'package:smartspace/projets/models/projet.dart';
import 'package:smartspace/projets/models/statut_tache.dart';
import 'package:smartspace/projets/models/tache.dart';
import 'package:smartspace/projets/services/projet_access.dart';
import 'package:smartspace/projets/services/projet_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const admin = Acteur(utilisateurId: 999, role: UserRole.administrateur);

void main() {
  late Database db;
  late ProjetService service;
  late Acteur acteurCourant;

  Future<User> ajouterUser(String email, UserRole role) async {
    final id = await db.insert(
      'users',
      User(
        fullName: email,
        email: email,
        passwordHash: 'x',
        role: role,
        avatarSeed: 'x',
        createdAt: DateTime(2026),
      ).toMap(),
    );
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return User.fromMap(rows.first);
  }

  // Écrit directement en base : le créateur d'un projet de test est libre.
  Future<int> ajouterProjet({int? createurId, String titre = 'Projet'}) =>
      db.insert(
        'projets',
        Projet(
          titre: titre,
          description: 'Description',
          dateCreation: '2026-01-01',
          createurId: createurId,
        ).toMap(),
      );

  Tache tache(
    int projetId, {
    int? id,
    String titre = 'Tâche',
    String debut = '2026-03-01',
    String fin = '2026-03-05',
    UserRole role = UserRole.uiuxDesigner,
    StatutTache statut = StatutTache.aFaire,
    int? utilisateurId,
  }) =>
      Tache(
        id: id,
        titre: titre,
        description: 'Description',
        dateDebut: debut,
        dateFin: fin,
        roleRequis: role,
        statut: statut,
        projetId: projetId,
        utilisateurId: utilisateurId,
      );

  // Écrit directement en base, sans passer par les vérifications du service.
  Future<int> tacheEnBase(
    int projetId, {
    String titre = 'Tâche',
    String debut = '2026-03-01',
    String fin = '2026-03-05',
    UserRole role = UserRole.uiuxDesigner,
    StatutTache statut = StatutTache.aFaire,
    int? utilisateurId,
  }) =>
      db.insert(
        'taches',
        tache(projetId,
                titre: titre,
                debut: debut,
                fin: fin,
                role: role,
                statut: statut,
                utilisateurId: utilisateurId)
            .toMap(),
      );

  Future<Tache> lire(int id) async {
    final rows = await db.query('taches', where: 'id = ?', whereArgs: [id]);
    return Tache.fromMap(rows.first);
  }

  Future<List<List<Map<String, Object?>>>> instantane() async =>
      [await db.query('projets'), await db.query('taches')];

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: false,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: (d, _) async {
          await UserDatabase.createTables(d);
          await ProjetDatabase.createTables(d);
        },
      ),
    );
    acteurCourant = admin;
    service = ProjetService(
      database: Future.value(db),
      lireUtilisateurs: () async =>
          (await db.query('users')).map(User.fromMap).toList(),
      acteur: () => acteurCourant,
    );
  });

  tearDown(() => db.close());

  group('Suppression en cascade', () {
    test('un projet peut exister sans aucune tâche', () async {
      final id = await ajouterProjet();
      expect(await service.getTachesProjet(id), isEmpty);
      expect((await service.getProjets()).single.id, id);
    });

    test('supprimer un projet supprime ses tâches, pas celles des autres',
        () async {
      final p1 = await ajouterProjet();
      final p2 = await ajouterProjet();
      await service.creerTache(tache(p1));
      await service.creerTache(tache(p1));
      final gardee = await service.creerTache(tache(p2));

      await service.supprimerProjet(p1);

      final restantes = await db.query('taches');
      expect(restantes.map((r) => r['id']), [gardee]);
    });
  });

  group('Suppression d\'un utilisateur (SET NULL)', () {
    test('sa tâche reste, sans affectation, avec son statut', () async {
      final u = await ajouterUser('a@x.tn', UserRole.uiuxDesigner);
      final p = await ajouterProjet();
      final t = await service.creerTache(tache(p));
      await service.affecterA(await lire(t), u);
      await service.changerStatut(t, StatutTache.enCours);

      await db.delete('users', where: 'id = ?', whereArgs: [u.id]);

      final apres = await lire(t);
      expect(apres.utilisateurId, isNull);
      expect(apres.estAffectee, isFalse);
      expect(apres.statut, StatutTache.enCours);
    });

    test('son projet reste, sans créateur, avec ses tâches', () async {
      final u = await ajouterUser('a@x.tn', UserRole.scrumMaster);
      final p = await ajouterProjet(createurId: u.id);
      await service.creerTache(tache(p));

      await db.delete('users', where: 'id = ?', whereArgs: [u.id]);

      expect((await service.getProjets()).single.createurId, isNull);
      expect(await service.getTachesProjet(p), hasLength(1));
    });
  });

  group('Contrainte CHECK sur le statut', () {
    Map<String, Object?> ligne(int p, String statut) =>
        {...tache(p).toMap(), 'statut': statut};

    test('chaque valeur de StatutTache est acceptée', () async {
      final p = await ajouterProjet();
      for (final s in StatutTache.values) {
        final id = await db.insert('taches', ligne(p, s.name));
        expect((await lire(id)).statut, s);
      }
    });

    test('un texte libre est refusé à l\'insertion', () async {
      final p = await ajouterProjet();
      for (final s in ['fini', 'À faire', 'TERMINEE', '']) {
        await expectLater(
            db.insert('taches', ligne(p, s)), throwsA(isA<DatabaseException>()));
      }
      expect(await db.query('taches'), isEmpty);
    });

    test('un texte libre est refusé à la mise à jour', () async {
      final p = await ajouterProjet();
      final t = await service.creerTache(tache(p));
      await expectLater(
        db.update('taches', {'statut': 'fini'},
            where: 'id = ?', whereArgs: [t]),
        throwsA(isA<DatabaseException>()),
      );
      expect((await lire(t)).statut, StatutTache.aFaire);
    });
  });

  group('Intégrité', () {
    test('une tâche sur un projet inexistant est refusée', () async {
      await expectLater(
          service.creerTache(tache(999)), throwsA(isA<ProjetException>()));
    });

    test('la base refuse aussi un projet inexistant (clés étrangères)',
        () async {
      await expectLater(db.insert('taches', tache(999).toMap()),
          throwsA(isA<DatabaseException>()));
    });

    test('une fin avant le début est refusée à la création', () async {
      final p = await ajouterProjet();
      await expectLater(
        service.creerTache(tache(p, debut: '2026-03-05', fin: '2026-03-01')),
        throwsA(isA<ProjetException>()),
      );
      expect(await service.getTachesProjet(p), isEmpty);
    });

    test('une fin avant le début est refusée à la modification', () async {
      final p = await ajouterProjet();
      final t = await service.creerTache(tache(p));
      await expectLater(
        service.modifierTache(
            tache(p, id: t, debut: '2026-03-05', fin: '2026-03-01')),
        throwsA(isA<ProjetException>()),
      );
      expect((await lire(t)).dateDebut, '2026-03-01');
    });

    test('la base refuse aussi une fin avant le début', () async {
      final p = await ajouterProjet();
      await expectLater(
        db.insert('taches',
            tache(p, debut: '2026-03-05', fin: '2026-03-01').toMap()),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('début et fin le même jour sont acceptés', () async {
      final p = await ajouterProjet();
      final t = await service
          .creerTache(tache(p, debut: '2026-03-01', fin: '2026-03-01'));
      expect((await lire(t)).dateFin, '2026-03-01');
    });
  });

  group('Écritures limitées', () {
    test('creerTache ignore une affectation fournie', () async {
      final u = await ajouterUser('a@x.tn', UserRole.uiuxDesigner);
      final p = await ajouterProjet();
      final t = await service.creerTache(tache(p, utilisateurId: u.id));
      expect((await lire(t)).utilisateurId, isNull);
    });

    test('modifierTache conserve le statut et l\'affectation', () async {
      final u = await ajouterUser('a@x.tn', UserRole.uiuxDesigner);
      final p = await ajouterProjet();
      final t = await service.creerTache(tache(p));
      await service.affecterA(await lire(t), u);
      await service.changerStatut(t, StatutTache.enCours);

      // Formulaire périmé : ni statut à jour, ni affectation.
      await service.modifierTache(tache(p, id: t, titre: 'Nouveau titre'));

      final apres = await lire(t);
      expect(apres.titre, 'Nouveau titre');
      expect(apres.statut, StatutTache.enCours);
      expect(apres.utilisateurId, u.id);
    });

    test('modifierProjet conserve la date de création et le créateur',
        () async {
      final u = await ajouterUser('a@x.tn', UserRole.scrumMaster);
      final p = await ajouterProjet(createurId: u.id);

      await service.modifierProjet(Projet(
          id: p, titre: 'Nouveau', description: 'D', dateCreation: '2030-12-31'));

      final apres = (await service.getProjets()).single;
      expect(apres.titre, 'Nouveau');
      expect(apres.dateCreation, '2026-01-01');
      expect(apres.createurId, u.id);
    });
  });

  group('affecterA', () {
    test('affecte une personne ayant le rôle requis', () async {
      final u = await ajouterUser('a@x.tn', UserRole.uiuxDesigner);
      final p = await ajouterProjet(titre: 'Refonte');
      final t = await service.creerTache(tache(p));

      await service.affecterA(await lire(t), u);

      final miennes = await service.getTachesUtilisateur(u.id!);
      expect(miennes.single.id, t);
      expect(miennes.single.projetTitre, 'Refonte');
    });

    test('refuse un mauvais rôle sans rien écrire', () async {
      final u = await ajouterUser('a@x.tn', UserRole.developpeur);
      final p = await ajouterProjet();
      final t = await service.creerTache(tache(p));

      await expectLater(service.affecterA(await lire(t), u),
          throwsA(isA<ProjetException>()));
      expect((await lire(t)).utilisateurId, isNull);
    });

    test('vérifie le rôle en base, pas celui d\'une tâche périmée', () async {
      final u = await ajouterUser('a@x.tn', UserRole.uiuxDesigner);
      final p = await ajouterProjet();
      final t = await service.creerTache(tache(p));
      final perimee = await lire(t);
      await service.modifierTache(tache(p, id: t, role: UserRole.developpeur));

      await expectLater(
          service.affecterA(perimee, u), throwsA(isA<ProjetException>()));
      expect((await lire(t)).utilisateurId, isNull);
    });

    test('refuse une tâche terminée', () async {
      final u = await ajouterUser('a@x.tn', UserRole.uiuxDesigner);
      final p = await ajouterProjet();
      final t = await service.creerTache(tache(p));
      await service.changerStatut(t, StatutTache.terminee);

      await expectLater(service.affecterA(await lire(t), u),
          throwsA(isA<ProjetException>()));
    });

    test('refuse une tâche supprimée entre-temps', () async {
      final u = await ajouterUser('a@x.tn', UserRole.uiuxDesigner);
      final p = await ajouterProjet();
      final t = await service.creerTache(tache(p));
      final perimee = await lire(t);
      await service.supprimerTache(t);

      await expectLater(
          service.affecterA(perimee, u), throwsA(isA<ProjetException>()));
    });

    test('refuse une personne occupée et nomme la tâche en conflit', () async {
      final u = await ajouterUser('a@x.tn', UserRole.uiuxDesigner);
      final p = await ajouterProjet(titre: 'Refonte');
      final occupe = await tacheEnBase(p,
          titre: 'Charte graphique',
          debut: '2026-03-03',
          fin: '2026-03-10',
          utilisateurId: u.id);
      final t = await tacheEnBase(p);

      final erreur = await service
          .affecterA(await lire(t), u)
          .then<ConflitAffectationException?>((_) => null)
          .catchError((Object e) => e as ConflitAffectationException);

      expect(erreur!.conflit!.id, occupe);
      expect(erreur.message, contains('Charte graphique'));
      expect(erreur.message, contains('Refonte'));
      expect((await lire(t)).utilisateurId, isNull);
    });

    test('des dates qui se touchent sont un conflit', () async {
      final u = await ajouterUser('a@x.tn', UserRole.uiuxDesigner);
      final p = await ajouterProjet();
      await tacheEnBase(p,
          debut: '2026-03-05', fin: '2026-03-10', utilisateurId: u.id);
      final t = await tacheEnBase(p, debut: '2026-03-01', fin: '2026-03-05');

      await expectLater(service.affecterA(await lire(t), u),
          throwsA(isA<ConflitAffectationException>()));
    });

    test('une tâche terminée de la personne ne bloque pas', () async {
      final u = await ajouterUser('a@x.tn', UserRole.uiuxDesigner);
      final p = await ajouterProjet();
      await tacheEnBase(p, statut: StatutTache.terminee, utilisateurId: u.id);
      final t = await tacheEnBase(p);

      await service.affecterA(await lire(t), u);
      expect((await lire(t)).utilisateurId, u.id);
    });

    test('réaffecter la même personne : pas de conflit avec soi-même',
        () async {
      final u = await ajouterUser('a@x.tn', UserRole.uiuxDesigner);
      final p = await ajouterProjet();
      final t = await tacheEnBase(p, utilisateurId: u.id);

      await service.affecterA(await lire(t), u);
      expect((await lire(t)).utilisateurId, u.id);
    });

    test('Mes tâches ne contient que les tâches de la personne', () async {
      final a = await ajouterUser('a@x.tn', UserRole.uiuxDesigner);
      final b = await ajouterUser('b@x.tn', UserRole.uiuxDesigner);
      final p = await ajouterProjet();
      final ta = await service.creerTache(tache(p));
      final tb = await service.creerTache(tache(p));
      await service.affecterA(await lire(ta), a);
      await service.affecterA(await lire(tb), b);

      expect((await service.getTachesUtilisateur(a.id!)).map((t) => t.id), [ta]);
    });
  });

  group('Candidats', () {
    test('getCandidats ne renvoie que le rôle exact', () async {
      final d = await ajouterUser('d@x.tn', UserRole.uiuxDesigner);
      await ajouterUser('e@x.tn', UserRole.developpeur);
      await ajouterUser('admin@x.tn', UserRole.administrateur);

      final candidats = await service.getCandidats(UserRole.uiuxDesigner);
      expect(candidats.map((u) => u.id), [d.id]);
    });

    test('aucun utilisateur n\'a ce rôle : liste vide', () async {
      await ajouterUser('e@x.tn', UserRole.developpeur);
      final p = await ajouterProjet();
      final t = await tacheEnBase(p, role: UserRole.rh);

      expect(await service.getCandidats(UserRole.rh), isEmpty);
      expect(await service.evaluerCandidats(await lire(t)), isEmpty);
    });

    test('disponibles d\'abord, occupés avec leur tâche en conflit', () async {
      final occupe = await ajouterUser('a@x.tn', UserRole.uiuxDesigner);
      final libre = await ajouterUser('b@x.tn', UserRole.uiuxDesigner);
      final p = await ajouterProjet(titre: 'Refonte');
      final bloquante = await tacheEnBase(p,
          titre: 'Charte', utilisateurId: occupe.id);
      final t = await tacheEnBase(p);

      final candidats = await service.evaluerCandidats(await lire(t));

      expect(candidats.map((c) => c.utilisateur.id), [libre.id, occupe.id]);
      expect(candidats[0].disponibilite.estDisponible, isTrue);
      expect(candidats[1].disponibilite.estDisponible, isFalse);
      expect(candidats[1].disponibilite.conflit!.id, bloquante);
      expect(candidats[1].disponibilite.conflit!.projetTitre, 'Refonte');
    });

    test('la personne déjà affectée à cette tâche reste disponible', () async {
      final u = await ajouterUser('a@x.tn', UserRole.uiuxDesigner);
      final p = await ajouterProjet();
      final t = await tacheEnBase(p, utilisateurId: u.id);

      final candidats = await service.evaluerCandidats(await lire(t));
      expect(candidats.single.disponibilite.estDisponible, isTrue);
    });
  });

  group('Revérification à la modification', () {
    late User u;
    late int p;
    late int autre;
    late int t;

    setUp(() async {
      u = await ajouterUser('a@x.tn', UserRole.uiuxDesigner);
      p = await ajouterProjet();
      autre = await tacheEnBase(p,
          titre: 'Autre', debut: '2026-03-10', fin: '2026-03-15', utilisateurId: u.id);
      t = await tacheEnBase(p,
          debut: '2026-03-01', fin: '2026-03-05', utilisateurId: u.id);
    });

    test('nouvelles dates en conflit : refus, tâche nommée, rien d\'écrit',
        () async {
      final avant = await instantane();
      final erreur = await service
          .modifierTache(tache(p, id: t, debut: '2026-03-08', fin: '2026-03-12'))
          .then<ConflitAffectationException?>((_) => null)
          .catchError((Object e) => e as ConflitAffectationException);

      expect(erreur!.conflit!.id, autre);
      expect(erreur.message, contains('Autre'));
      expect(await instantane(), avant);
    });

    test('nouvelles dates libres : enregistré, affectation conservée',
        () async {
      await service.modifierTache(
          tache(p, id: t, debut: '2026-03-20', fin: '2026-03-25'));

      final apres = await lire(t);
      expect(apres.dateDebut, '2026-03-20');
      expect(apres.utilisateurId, u.id);
    });

    test('décaler ses dates sur son ancienne période : pas de conflit',
        () async {
      await service.modifierTache(
          tache(p, id: t, debut: '2026-03-03', fin: '2026-03-07'));
      expect((await lire(t)).dateFin, '2026-03-07');
    });

    test('une tâche terminée en face ne bloque pas', () async {
      await service.changerStatut(autre, StatutTache.terminee);
      await service.modifierTache(
          tache(p, id: t, debut: '2026-03-10', fin: '2026-03-15'));
      expect((await lire(t)).dateDebut, '2026-03-10');
    });

    test('rôle requis changé vers un rôle que la personne n\'a pas : refus',
        () async {
      final avant = await instantane();
      final erreur = await service
          .modifierTache(tache(p, id: t, role: UserRole.developpeur))
          .then<ConflitAffectationException?>((_) => null)
          .catchError((Object e) => e as ConflitAffectationException);

      expect(erreur!.conflit, isNull);
      expect(erreur.message, contains('Développeur'));
      expect(await instantane(), avant);
    });

    test('retirer l\'affectation : enregistre et libère la tâche', () async {
      await service.modifierTache(
        tache(p, id: t, debut: '2026-03-08', fin: '2026-03-12'),
        retirerAffectation: true,
      );

      final apres = await lire(t);
      expect(apres.dateDebut, '2026-03-08');
      expect(apres.utilisateurId, isNull);
    });

    test('titre ou description seuls : jamais de revérification', () async {
      // Conflit déjà présent en base : seul un re-contrôle pourrait refuser.
      await db.update(
          'taches', {'date_debut': '2026-03-10', 'date_fin': '2026-03-15'},
          where: 'id = ?', whereArgs: [t]);

      await service.modifierTache(tache(p,
          id: t,
          titre: 'Nouveau titre',
          debut: '2026-03-10',
          fin: '2026-03-15'));

      final apres = await lire(t);
      expect(apres.titre, 'Nouveau titre');
      expect(apres.utilisateurId, u.id);
    });

    test('tâche non affectée : aucune revérification', () async {
      final libre = await tacheEnBase(p);
      await service.modifierTache(tache(p,
          id: libre, debut: '2026-03-10', fin: '2026-03-15', role: UserRole.rh));
      expect((await lire(libre)).roleRequis, UserRole.rh);
    });

    test('tâche terminée : ses dates sont libres, elle ne bloque personne',
        () async {
      await service.changerStatut(t, StatutTache.terminee);
      await service.modifierTache(
          tache(p, id: t, debut: '2026-03-10', fin: '2026-03-15'));
      expect((await lire(t)).dateDebut, '2026-03-10');
    });
  });

  group('Réouverture d\'une tâche terminée', () {
    late User u;
    late int p;
    late int t;

    setUp(() async {
      u = await ajouterUser('a@x.tn', UserRole.uiuxDesigner);
      p = await ajouterProjet();
      t = await tacheEnBase(p, statut: StatutTache.terminee, utilisateurId: u.id);
    });

    Future<int> creerCollision() =>
        tacheEnBase(p, titre: 'Collision', utilisateurId: u.id);

    test('en conflit : refus, reste terminée', () async {
      final collision = await creerCollision();
      final erreur = await service
          .changerStatut(t, StatutTache.enCours)
          .then<ConflitAffectationException?>((_) => null)
          .catchError((Object e) => e as ConflitAffectationException);

      expect(erreur!.conflit!.id, collision);
      expect((await lire(t)).statut, StatutTache.terminee);
      expect((await lire(t)).utilisateurId, u.id);
    });

    test('vers « à faire » aussi', () async {
      await creerCollision();
      await expectLater(service.changerStatut(t, StatutTache.aFaire),
          throwsA(isA<ConflitAffectationException>()));
    });

    test('retirer l\'affectation : rouvre et libère', () async {
      await creerCollision();
      await service.changerStatut(t, StatutTache.enCours,
          retirerAffectation: true);

      final apres = await lire(t);
      expect(apres.statut, StatutTache.enCours);
      expect(apres.utilisateurId, isNull);
    });

    test('sans conflit : rouverte, affectation conservée', () async {
      await service.changerStatut(t, StatutTache.enCours);
      final apres = await lire(t);
      expect(apres.statut, StatutTache.enCours);
      expect(apres.utilisateurId, u.id);
    });

    test('le rôle est aussi revérifié à la réouverture', () async {
      await db.update('taches', {'role_requis': UserRole.developpeur.index},
          where: 'id = ?', whereArgs: [t]);
      await expectLater(service.changerStatut(t, StatutTache.enCours),
          throwsA(isA<ConflitAffectationException>()));
    });

    test('passer de « à faire » à « en cours » ne revérifie rien', () async {
      await creerCollision();
      final enCours = await tacheEnBase(p, utilisateurId: u.id);

      await service.changerStatut(enCours, StatutTache.enCours);
      expect((await lire(enCours)).statut, StatutTache.enCours);
    });

    test('terminer une tâche en conflit est toujours possible', () async {
      final collision = await creerCollision();
      await tacheEnBase(p, utilisateurId: u.id);

      await service.changerStatut(collision, StatutTache.terminee);
      expect((await lire(collision)).statut, StatutTache.terminee);
    });
  });

  group('Droits dans le service', () {
    late User createur;
    late User autreScrum;
    late User designer;
    late int p;
    late int t;

    Acteur commeActeur(User u) => Acteur(utilisateurId: u.id!, role: u.role);

    setUp(() async {
      // Créateur rétrogradé en Employé : gérer dépend de la création, pas du rôle.
      createur = await ajouterUser('c@x.tn', UserRole.employe);
      autreScrum = await ajouterUser('s@x.tn', UserRole.scrumMaster);
      designer = await ajouterUser('d@x.tn', UserRole.uiuxDesigner);
      p = await ajouterProjet(createurId: createur.id);
      t = await tacheEnBase(p);
    });

    final actions = <String, Future<void> Function()>{};

    setUp(() {
      actions.addAll({
        'modifierProjet': () => service.modifierProjet(Projet(
            id: p, titre: 'N', description: 'D', dateCreation: '2026-01-01')),
        'supprimerProjet': () => service.supprimerProjet(p),
        'creerTache': () => service.creerTache(tache(p)),
        'modifierTache': () =>
            service.modifierTache(tache(p, id: t, titre: 'N')),
        'supprimerTache': () => service.supprimerTache(t),
        'affecterA': () async => service.affecterA(await lire(t), designer),
      });
    });

    for (final nom in [
      'modifierProjet',
      'supprimerProjet',
      'creerTache',
      'modifierTache',
      'supprimerTache',
      'affecterA',
    ]) {
      test('$nom : refusé à un non-créateur non-admin, sans effet', () async {
        acteurCourant = commeActeur(autreScrum);
        final avant = await instantane();
        await expectLater(actions[nom]!(), throwsA(isA<AccesRefuseException>()));
        expect(await instantane(), avant);
      });

      test('$nom : autorisé au créateur', () async {
        acteurCourant = commeActeur(createur);
        await actions[nom]!();
      });

      test('$nom : autorisé à un administrateur', () async {
        acteurCourant = admin;
        await actions[nom]!();
      });

      test('$nom : refusé à une session déconnectée', () async {
        acteurCourant =
            const Acteur(utilisateurId: 0, role: UserRole.employe);
        await expectLater(actions[nom]!(), throwsA(isA<AccesRefuseException>()));
      });
    }

    test('projet sans créateur : non-admin refusé, admin autorisé', () async {
      final orphelin = await ajouterProjet();
      acteurCourant = commeActeur(autreScrum);
      await expectLater(service.supprimerProjet(orphelin),
          throwsA(isA<AccesRefuseException>()));
      acteurCourant = admin;
      await service.supprimerProjet(orphelin);
    });

    test('un objet Tache mensonger ne contourne pas les droits', () async {
      // autreScrum possède son projet et prétend que la tâche d'un autre y est.
      final sien = await ajouterProjet(createurId: autreScrum.id);
      acteurCourant = commeActeur(autreScrum);
      final avant = await instantane();

      await expectLater(service.modifierTache(tache(sien, id: t, titre: 'Volé')),
          throwsA(isA<AccesRefuseException>()));
      expect(await instantane(), avant);
    });

    group('creerProjet', () {
      Projet nouveau({int? createurId}) => Projet(
          titre: 'N',
          description: 'D',
          dateCreation: '2026-01-01',
          createurId: createurId);

      test('refusé aux rôles non autorisés par ModuleAccess', () async {
        for (final role in [
          UserRole.employe,
          UserRole.developpeur,
          UserRole.uiuxDesigner,
          UserRole.rh,
        ]) {
          acteurCourant = Acteur(utilisateurId: createur.id!, role: role);
          await expectLater(service.creerProjet(nouveau()),
              throwsA(isA<AccesRefuseException>()));
        }
        expect((await service.getProjets()).map((x) => x.id), [p]);
      });

      test('autorisé à un Scrum Master, qui en devient le créateur', () async {
        acteurCourant = commeActeur(autreScrum);
        final id = await service.creerProjet(nouveau());
        final cree = (await service.getProjets()).firstWhere((x) => x.id == id);
        expect(cree.createurId, autreScrum.id);
      });

      test('le créateur fourni est ignoré : c\'est toujours l\'acteur',
          () async {
        acteurCourant = commeActeur(autreScrum);
        final id = await service.creerProjet(nouveau(createurId: createur.id));
        final cree = (await service.getProjets()).firstWhere((x) => x.id == id);
        expect(cree.createurId, autreScrum.id);
      });
    });

    group('changerStatut', () {
      late int affectee;

      setUp(() async {
        affectee = await tacheEnBase(p, utilisateurId: designer.id);
      });

      test('autorisé à la personne affectée', () async {
        acteurCourant = commeActeur(designer);
        await service.changerStatut(affectee, StatutTache.enCours);
        expect((await lire(affectee)).statut, StatutTache.enCours);
      });

      test('autorisé au créateur et à un administrateur', () async {
        acteurCourant = commeActeur(createur);
        await service.changerStatut(affectee, StatutTache.enCours);
        acteurCourant = admin;
        await service.changerStatut(affectee, StatutTache.terminee);
        expect((await lire(affectee)).statut, StatutTache.terminee);
      });

      test('refusé à quelqu\'un d\'autre', () async {
        acteurCourant = commeActeur(autreScrum);
        await expectLater(service.changerStatut(affectee, StatutTache.enCours),
            throwsA(isA<AccesRefuseException>()));
        expect((await lire(affectee)).statut, StatutTache.aFaire);
      });
    });
  });
}
