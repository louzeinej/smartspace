import 'package:flutter_test/flutter_test.dart';
import 'package:smartspace/database/user_database.dart';
import 'package:smartspace/models/user_model.dart';
import 'package:smartspace/models/user_role.dart';
import 'package:smartspace/projets/data/projet_database.dart';
import 'package:smartspace/projets/models/projet.dart';
import 'package:smartspace/projets/models/statut_tache.dart';
import 'package:smartspace/projets/models/tache.dart';
import 'package:smartspace/projets/services/projet_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late ProjetService service;

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

  Future<int> ajouterProjet({int? createurId, String titre = 'Projet'}) =>
      service.creerProjet(Projet(
        titre: titre,
        description: 'Description',
        dateCreation: '2026-01-01',
        createurId: createurId,
      ));

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

  Future<Tache> lire(int id) async {
    final rows = await db.query('taches', where: 'id = ?', whereArgs: [id]);
    return Tache.fromMap(rows.first);
  }

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
    service = ProjetService(
      database: Future.value(db),
      lireUtilisateurs: () async =>
          (await db.query('users')).map(User.fromMap).toList(),
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
          service.creerTache(tache(999)), throwsA(isA<DatabaseException>()));
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

  group('getCandidats', () {
    test('ne renvoie que le rôle exact', () async {
      final d = await ajouterUser('d@x.tn', UserRole.uiuxDesigner);
      await ajouterUser('e@x.tn', UserRole.developpeur);
      await ajouterUser('admin@x.tn', UserRole.administrateur);

      final candidats = await service.getCandidats(UserRole.uiuxDesigner);
      expect(candidats.map((u) => u.id), [d.id]);
    });

    test('liste vide si personne n\'a ce rôle', () async {
      await ajouterUser('e@x.tn', UserRole.developpeur);
      expect(await service.getCandidats(UserRole.rh), isEmpty);
    });
  });
}
