import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspace/database/user_database.dart';
import 'package:smartspace/models/user_model.dart';
import 'package:smartspace/models/user_role.dart';
import 'package:smartspace/projets/data/projet_database.dart';
import 'package:smartspace/projets/models/projet.dart';
import 'package:smartspace/projets/models/statut_tache.dart';
import 'package:smartspace/projets/models/tache.dart';
import 'package:smartspace/projets/screens/mes_taches_screen.dart';
import 'package:smartspace/projets/screens/projet_detail_screen.dart';
import 'package:smartspace/projets/screens/projets_screen.dart';
import 'package:smartspace/projets/services/projet_access.dart';
import 'package:smartspace/projets/services/projet_service.dart';
import 'package:smartspace/theme/app_theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const admin = Acteur(utilisateurId: 999, role: UserRole.administrateur);

void main() {
  late Database db;
  late ProjetService service;
  late Acteur acteurCourant;
  late User createur;
  late User designer;
  late User autreDesigner;
  late User autreScrum;

  Acteur commeActeur(User u) => Acteur(utilisateurId: u.id!, role: u.role);

  Future<User> ajouterUser(String nom, UserRole role) async {
    final id = await db.insert(
      'users',
      User(
        fullName: nom,
        email: '${nom.replaceAll(' ', '.')}@x.tn',
        passwordHash: 'x',
        role: role,
        avatarSeed: 'x',
        createdAt: DateTime(2026),
      ).toMap(),
    );
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return User.fromMap(rows.first);
  }

  Future<int> ajouterProjet(int? createurId, {String titre = 'Refonte'}) =>
      db.insert(
        'projets',
        Projet(
          titre: titre,
          description: 'Description du projet',
          dateCreation: '2026-01-01',
          createurId: createurId,
        ).toMap(),
      );

  Future<int> ajouterTache(
    int projetId, {
    String titre = 'Maquette',
    String debut = '2026-03-01',
    String fin = '2026-03-05',
    UserRole role = UserRole.uiuxDesigner,
    StatutTache statut = StatutTache.aFaire,
    int? utilisateurId,
  }) =>
      db.insert(
        'taches',
        Tache(
          titre: titre,
          description: 'Description de la tâche',
          dateDebut: debut,
          dateFin: fin,
          roleRequis: role,
          statut: statut,
          projetId: projetId,
          utilisateurId: utilisateurId,
        ).toMap(),
      );

  /// Laisse les requêtes SQLite (de vrais E/S) et les animations se terminer :
  /// le temps des tests de widgets est simulé.
  Future<void> stabiliser(WidgetTester t) async {
    for (var i = 0; i < 30; i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 3)));
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> afficher(WidgetTester t, Widget ecran) async {
    await t.pumpWidget(MaterialApp(theme: AppTheme.light, home: ecran));
    await stabiliser(t);
  }

  Future<void> taper(WidgetTester t, Finder cible) async {
    await t.ensureVisible(cible);
    await t.pump();
    await t.tap(cible);
    await stabiliser(t);
  }

  Future<void> choisirJour(WidgetTester t, String champ, String jour) async {
    await taper(t, find.widgetWithText(TextFormField, champ));
    await t.tap(find.text(jour));
    await t.pump();
    await t.tap(find.text('OK'));
    await stabiliser(t);
  }

  Future<Tache> lireTache(WidgetTester t, int id) async {
    final rows = await t.runAsync(
        () => db.query('taches', where: 'id = ?', whereArgs: [id]));
    return Tache.fromMap(rows!.first);
  }

  Future<Projet> projetDe(WidgetTester t, int id) async {
    final p = await t.runAsync(() => service.getProjet(id));
    return p!;
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
    createur = await ajouterUser('Chef Projet', UserRole.scrumMaster);
    designer = await ajouterUser('Alice Design', UserRole.uiuxDesigner);
    autreDesigner = await ajouterUser('Bruno Design', UserRole.uiuxDesigner);
    autreScrum = await ajouterUser('Autre Scrum', UserRole.scrumMaster);
    acteurCourant = commeActeur(createur);
    service = ProjetService(
      database: Future.value(db),
      lireUtilisateurs: () async =>
          (await db.query('users')).map(User.fromMap).toList(),
      acteur: () => acteurCourant,
    );
  });

  tearDown(() => db.close());

  group('Créer un projet', () {
    testWidgets('état vide, validation, puis création par le Scrum Master',
        (t) async {
      await afficher(t, ProjetsScreen(service: service));
      expect(find.text('Aucun projet pour le moment.'), findsOneWidget);

      await taper(t, find.text('Nouveau projet'));
      await taper(t, find.text('Enregistrer'));
      expect(find.text('Le titre est obligatoire'), findsOneWidget);
      expect(find.text('La description est obligatoire'), findsOneWidget);

      await t.enterText(find.widgetWithText(TextFormField, 'Titre'), 'Site web');
      await t.enterText(
          find.widgetWithText(TextFormField, 'Description'), 'Nouveau site');
      await taper(t, find.text('Enregistrer'));

      expect(find.text('Site web'), findsOneWidget);
      expect(find.text('Aucun projet pour le moment.'), findsNothing);
      final projets = await t.runAsync(() => service.getProjets());
      expect(projets!.single.createurId, createur.id);
    });

    testWidgets('titre fait uniquement d\'espaces : refusé', (t) async {
      await afficher(t, ProjetsScreen(service: service));
      await taper(t, find.text('Nouveau projet'));
      await t.enterText(find.widgetWithText(TextFormField, 'Titre'), '   ');
      await taper(t, find.text('Enregistrer'));
      expect(find.text('Le titre est obligatoire'), findsOneWidget);
    });

    testWidgets('un Employé ne voit pas le bouton de création', (t) async {
      acteurCourant = const Acteur(utilisateurId: 42, role: UserRole.employe);
      await afficher(t, ProjetsScreen(service: service));
      expect(find.text('Nouveau projet'), findsNothing);
    });
  });

  group('Créer une tâche', () {
    testWidgets('état vide, validation, fin avant début, puis création',
        (t) async {
      final id = await t.runAsync(() => ajouterProjet(createur.id));
      await afficher(t,
          ProjetDetailScreen(service: service, projet: await projetDe(t, id!)));
      expect(find.text('Aucune tâche dans ce projet.'), findsOneWidget);

      await taper(t, find.text('Nouvelle tâche'));
      await taper(t, find.text('Enregistrer'));
      expect(find.text('Le titre est obligatoire'), findsOneWidget);
      expect(find.text('La date de début est obligatoire'), findsOneWidget);
      expect(find.text('La date de fin est obligatoire'), findsOneWidget);
      expect(find.text('Le rôle est obligatoire'), findsOneWidget);

      await t.enterText(
          find.widgetWithText(TextFormField, 'Titre'), 'Charte graphique');
      await t.enterText(
          find.widgetWithText(TextFormField, 'Description'), 'Couleurs');
      await choisirJour(t, 'Date de début', '20');
      await choisirJour(t, 'Date de fin', '10');
      await taper(t, find.byType(DropdownButtonFormField<UserRole>));
      await taper(t, find.text('UI/UX Designer').last);

      await taper(t, find.text('Enregistrer'));
      expect(find.text('La date de fin ne peut pas précéder la date de début'),
          findsOneWidget);
      expect(await t.runAsync(() => service.getTachesProjet(id)), isEmpty);

      await choisirJour(t, 'Date de fin', '25');
      await taper(t, find.text('Enregistrer'));

      expect(find.text('Charte graphique'), findsOneWidget);
      expect(find.text('Non affectée'), findsOneWidget);
      final taches = await t.runAsync(() => service.getTachesProjet(id));
      expect(taches!.single.roleRequis, UserRole.uiuxDesigner);
      expect(taches.single.statut, StatutTache.aFaire);
    });
  });

  group('Affectation', () {
    testWidgets('badges Disponible et Occupé, tâche en conflit, affectation',
        (t) async {
      final p = await t.runAsync(() => ajouterProjet(createur.id));
      final tacheId = await t.runAsync(() async {
        await ajouterTache(p!,
            titre: 'Charte',
            debut: '2026-03-03',
            fin: '2026-03-08',
            utilisateurId: designer.id);
        return ajouterTache(p);
      });
      await afficher(t,
          ProjetDetailScreen(service: service, projet: await projetDe(t, p!)));

      await taper(t, find.text('Affecter'));

      expect(find.text('Disponible'), findsOneWidget);
      expect(find.text('Occupé'), findsOneWidget);
      expect(find.textContaining('Sur « Charte » (Refonte)'), findsOneWidget);
      // Seule la personne disponible peut être choisie.
      expect(find.widgetWithText(TextButton, 'Affecter'), findsOneWidget);

      await taper(t, find.widgetWithText(TextButton, 'Affecter'));

      expect(find.text('Affectée à Bruno Design'), findsOneWidget);
      expect((await lireTache(t, tacheId!)).utilisateurId, autreDesigner.id);
    });

    testWidgets('aucun utilisateur n\'a le rôle requis', (t) async {
      final p = await t.runAsync(() => ajouterProjet(createur.id));
      await t.runAsync(() => ajouterTache(p!, role: UserRole.rh));
      await afficher(t,
          ProjetDetailScreen(service: service, projet: await projetDe(t, p!)));

      await taper(t, find.text('Affecter'));

      expect(find.text('Aucun utilisateur n\'a le rôle RH.'), findsOneWidget);
    });

    testWidgets('tâche terminée : pas de bouton Affecter', (t) async {
      final p = await t.runAsync(() => ajouterProjet(createur.id));
      await t.runAsync(() => ajouterTache(p!, statut: StatutTache.terminee));
      await afficher(t,
          ProjetDetailScreen(service: service, projet: await projetDe(t, p!)));

      expect(find.text('Affecter'), findsNothing);
      expect(find.byTooltip('Modifier la tâche'), findsOneWidget);
    });
  });

  group('Dialogue de conflit', () {
    testWidgets('nomme la tâche ; Annuler ne change rien ; Retirer enregistre',
        (t) async {
      final p = await t.runAsync(() => ajouterProjet(createur.id));
      final tacheId = await t.runAsync(() async {
        await ajouterTache(p!,
            titre: 'Bloquante',
            debut: '2026-03-10',
            fin: '2026-03-15',
            utilisateurId: designer.id);
        return ajouterTache(p, utilisateurId: designer.id);
      });
      await afficher(t,
          ProjetDetailScreen(service: service, projet: await projetDe(t, p!)));

      await taper(t, find.byTooltip('Modifier la tâche').first);
      await choisirJour(t, 'Date de début', '12');
      await choisirJour(t, 'Date de fin', '14');
      await taper(t, find.text('Enregistrer'));

      expect(find.text('Enregistrement impossible'), findsOneWidget);
      expect(find.textContaining('Bloquante'), findsOneWidget);
      expect(find.text('Retirer l\'affectation et enregistrer'), findsOneWidget);

      await taper(t, find.text('Annuler'));
      expect(find.text('Modifier la tâche'), findsOneWidget);
      var apres = await lireTache(t, tacheId!);
      expect(apres.dateDebut, '2026-03-01');
      expect(apres.utilisateurId, designer.id);

      await taper(t, find.text('Enregistrer'));
      await taper(t, find.text('Retirer l\'affectation et enregistrer'));

      apres = await lireTache(t, tacheId);
      expect(apres.dateDebut, '2026-03-12');
      expect(apres.dateFin, '2026-03-14');
      expect(apres.utilisateurId, isNull);
      expect(find.text('Modifier la tâche'), findsNothing);
    });

    testWidgets('changer seulement le titre : aucun dialogue', (t) async {
      final p = await t.runAsync(() => ajouterProjet(createur.id));
      final tacheId = await t.runAsync(() async {
        await ajouterTache(p!, titre: 'Bloquante', utilisateurId: designer.id);
        return ajouterTache(p, titre: 'Zeta', utilisateurId: designer.id);
      });
      await afficher(t,
          ProjetDetailScreen(service: service, projet: await projetDe(t, p!)));

      await taper(t, find.byTooltip('Modifier la tâche').last);
      await t.enterText(find.widgetWithText(TextFormField, 'Titre'), 'Renommée');
      await taper(t, find.text('Enregistrer'));

      expect(find.text('Enregistrement impossible'), findsNothing);
      final apres = await lireTache(t, tacheId!);
      expect(apres.titre, 'Renommée');
      expect(apres.utilisateurId, designer.id);
    });
  });

  group('Mes tâches', () {
    Future<void> choisirStatut(WidgetTester t, String label) async {
      await taper(t, find.byType(DropdownButton<StatutTache>));
      await taper(t, find.text(label).last);
    }

    testWidgets('aucune tâche affectée : état vide', (t) async {
      acteurCourant = commeActeur(designer);
      await afficher(t, Scaffold(body: MesTachesScreen(service: service)));
      expect(find.text('Aucune tâche ne vous est affectée.'), findsOneWidget);
    });

    testWidgets('n\'affiche que mes tâches, avec le nom du projet', (t) async {
      final p = await t.runAsync(() => ajouterProjet(createur.id));
      await t.runAsync(() async {
        await ajouterTache(p!, titre: 'La mienne', utilisateurId: designer.id);
        await ajouterTache(p,
            titre: 'Celle d\'un autre', utilisateurId: autreDesigner.id);
      });
      acteurCourant = commeActeur(designer);
      await afficher(t, Scaffold(body: MesTachesScreen(service: service)));

      expect(find.text('La mienne'), findsOneWidget);
      expect(find.text('Celle d\'un autre'), findsNothing);
      expect(find.text('Projet : Refonte'), findsOneWidget);
    });

    testWidgets('changer le statut l\'enregistre et recharge la liste',
        (t) async {
      final p = await t.runAsync(() => ajouterProjet(createur.id));
      final tacheId = await t
          .runAsync(() => ajouterTache(p!, utilisateurId: designer.id));
      acteurCourant = commeActeur(designer);
      await afficher(t, Scaffold(body: MesTachesScreen(service: service)));

      await choisirStatut(t, 'En cours');

      expect((await lireTache(t, tacheId!)).statut, StatutTache.enCours);
      final menu = t.widget<DropdownButton<StatutTache>>(
          find.byType(DropdownButton<StatutTache>));
      expect(menu.value, StatutTache.enCours);
    });

    testWidgets('rouvrir en conflit : refus, le menu revient à Terminée',
        (t) async {
      final p = await t.runAsync(() => ajouterProjet(createur.id));
      final tacheId = await t.runAsync(() async {
        await ajouterTache(p!,
            titre: 'Bloquante',
            debut: '2026-04-01',
            fin: '2026-04-02',
            utilisateurId: designer.id);
        return ajouterTache(p,
            titre: 'Finie',
            debut: '2026-04-01',
            fin: '2026-04-02',
            statut: StatutTache.terminee,
            utilisateurId: designer.id);
      });
      acteurCourant = commeActeur(designer);
      await afficher(t, Scaffold(body: MesTachesScreen(service: service)));

      await taper(t, find.byType(DropdownButton<StatutTache>).last);
      await taper(t, find.text('En cours').last);

      expect(find.text('Enregistrement impossible'), findsOneWidget);
      expect(find.textContaining('Bloquante'), findsWidgets);

      await taper(t, find.text('Annuler'));

      expect((await lireTache(t, tacheId!)).statut, StatutTache.terminee);
      final menu = t.widget<DropdownButton<StatutTache>>(
          find.byType(DropdownButton<StatutTache>).last);
      expect(menu.value, StatutTache.terminee);
    });

    testWidgets('rouvrir en conflit puis retirer : la tâche quitte ma liste',
        (t) async {
      final p = await t.runAsync(() => ajouterProjet(createur.id));
      final tacheId = await t.runAsync(() async {
        await ajouterTache(p!, titre: 'Bloquante', utilisateurId: designer.id);
        return ajouterTache(p,
            titre: 'Finie',
            statut: StatutTache.terminee,
            utilisateurId: designer.id);
      });
      acteurCourant = commeActeur(designer);
      await afficher(t, Scaffold(body: MesTachesScreen(service: service)));

      await taper(t, find.byType(DropdownButton<StatutTache>).last);
      await taper(t, find.text('En cours').last);
      await taper(t, find.text('Retirer l\'affectation et enregistrer'));

      final apres = await lireTache(t, tacheId!);
      expect(apres.statut, StatutTache.enCours);
      expect(apres.utilisateurId, isNull);
      expect(find.text('Finie'), findsNothing);
      expect(find.text('Bloquante'), findsOneWidget);
    });
  });

  group('Droits à l\'écran', () {
    const boutons = [
      'Modifier le projet',
      'Supprimer le projet',
      'Modifier la tâche',
      'Supprimer la tâche',
    ];

    Future<void> afficherDetail(WidgetTester t, int p) async {
      await afficher(t,
          ProjetDetailScreen(service: service, projet: await projetDe(t, p)));
    }

    Future<int> projetAvecTache(WidgetTester t) async {
      final p = await t.runAsync(() => ajouterProjet(createur.id));
      await t.runAsync(() => ajouterTache(p!));
      return p!;
    }

    void attendreBoutons(Matcher attendu) {
      for (final b in boutons) {
        expect(find.byTooltip(b), attendu, reason: b);
      }
      expect(find.text('Affecter'), attendu);
      expect(find.text('Nouvelle tâche'), attendu);
    }

    testWidgets('un non-créateur non-admin ne voit aucune action', (t) async {
      final p = await projetAvecTache(t);
      acteurCourant = commeActeur(autreScrum);
      await afficherDetail(t, p);

      expect(find.text('Maquette'), findsOneWidget);
      attendreBoutons(findsNothing);
    });

    testWidgets('le créateur voit toutes les actions', (t) async {
      final p = await projetAvecTache(t);
      await afficherDetail(t, p);
      attendreBoutons(findsOneWidget);
    });

    testWidgets('un administrateur voit toutes les actions', (t) async {
      final p = await projetAvecTache(t);
      acteurCourant = admin;
      await afficherDetail(t, p);
      attendreBoutons(findsOneWidget);
    });

    const messageRefus =
        'Seuls le créateur du projet ou un administrateur peuvent faire cette action.';

    testWidgets('droits perdus écran ouvert : suppression de tâche refusée',
        (t) async {
      final p = await projetAvecTache(t);
      await afficherDetail(t, p);

      acteurCourant = commeActeur(autreScrum);
      await taper(t, find.byTooltip('Supprimer la tâche'));
      await taper(t, find.text('Supprimer'));

      expect(find.text(messageRefus), findsOneWidget);
      expect(await t.runAsync(() => service.getTachesProjet(p)), hasLength(1));
    });

    testWidgets('droits perdus écran ouvert : suppression de projet refusée',
        (t) async {
      final p = await projetAvecTache(t);
      await afficherDetail(t, p);

      acteurCourant = commeActeur(autreScrum);
      await taper(t, find.byTooltip('Supprimer le projet'));
      await taper(t, find.text('Supprimer'));

      expect(find.text(messageRefus), findsOneWidget);
      expect(await t.runAsync(() => service.getProjets()), hasLength(1));
    });

    testWidgets('droits perdus écran ouvert : modification refusée', (t) async {
      final p = await projetAvecTache(t);
      await afficherDetail(t, p);

      await taper(t, find.byTooltip('Modifier le projet'));
      acteurCourant = commeActeur(autreScrum);
      await t.enterText(find.widgetWithText(TextFormField, 'Titre'), 'Piraté');
      await taper(t, find.text('Enregistrer'));

      expect(find.text(messageRefus), findsOneWidget);
      expect((await t.runAsync(() => service.getProjets()))!.single.titre,
          'Refonte');
    });

    testWidgets('droits perdus écran ouvert : affectation refusée', (t) async {
      final p = await projetAvecTache(t);
      await afficherDetail(t, p);

      await taper(t, find.text('Affecter'));
      acteurCourant = commeActeur(autreScrum);
      await taper(t, find.widgetWithText(TextButton, 'Affecter').first);

      expect(find.text(messageRefus), findsOneWidget);
      final taches = await t.runAsync(() => service.getTachesProjet(p));
      expect(taches!.single.utilisateurId, isNull);
    });
  });
}
