import 'package:flutter_test/flutter_test.dart';
import 'package:smartspace/models/user_role.dart';
import 'package:smartspace/projets/models/statut_tache.dart';
import 'package:smartspace/projets/models/tache.dart';
import 'package:smartspace/projets/services/disponibilite_service.dart';

Tache tache(
  String debut,
  String fin, {
  int? id,
  String titre = 'Existante',
  StatutTache statut = StatutTache.aFaire,
}) =>
    Tache(
      id: id,
      titre: titre,
      description: 'D',
      dateDebut: debut,
      dateFin: fin,
      roleRequis: UserRole.uiuxDesigner,
      statut: statut,
      projetId: 1,
      utilisateurId: 1,
    );

Disponibilite verifier(
  String debut,
  String fin,
  List<Tache> taches, {
  int? ignoree,
  bool disponible = true,
}) =>
    verifierDisponibilite(
      dateDebut: debut,
      dateFin: fin,
      tachesDeLaPersonne: taches,
      tacheIgnoreeId: ignoree,
      disponible: disponible,
    );

void main() {
  group('Chevauchement', () {
    final existante = tache('2026-03-10', '2026-03-20', id: 1);

    test('aucune tâche : disponible', () {
      final r = verifier('2026-03-10', '2026-03-20', []);
      expect(r.estDisponible, isTrue);
      expect(r.conflit, isNull);
    });

    test('dates identiques : conflit', () {
      expect(verifier('2026-03-10', '2026-03-20', [existante]).conflit, existante);
    });

    test('finit le jour où l\'autre commence : conflit', () {
      expect(verifier('2026-03-01', '2026-03-10', [existante]).conflit, existante);
    });

    test('commence le jour où l\'autre finit : conflit', () {
      expect(verifier('2026-03-20', '2026-03-25', [existante]).conflit, existante);
    });

    test('tâche entièrement à l\'intérieur de l\'autre : conflit', () {
      expect(verifier('2026-03-12', '2026-03-15', [existante]).conflit, existante);
    });

    test('tâche qui englobe l\'autre : conflit', () {
      expect(verifier('2026-03-01', '2026-03-31', [existante]).conflit, existante);
    });

    test('chevauchement partiel : conflit', () {
      expect(verifier('2026-03-05', '2026-03-12', [existante]).conflit, existante);
      expect(verifier('2026-03-18', '2026-03-25', [existante]).conflit, existante);
    });

    test('tâche d\'un seul jour sur une borne : conflit', () {
      expect(verifier('2026-03-20', '2026-03-20', [existante]).conflit, existante);
    });

    test('finit la veille : disponible', () {
      expect(verifier('2026-03-01', '2026-03-09', [existante]).estDisponible, isTrue);
    });

    test('commence le lendemain : disponible', () {
      expect(verifier('2026-03-21', '2026-03-25', [existante]).estDisponible, isTrue);
    });

    test('à cheval sur deux mois et deux années', () {
      final mois = tache('2026-09-28', '2026-10-03');
      expect(verifier('2026-10-01', '2026-10-02', [mois]).conflit, mois);
      expect(verifier('2026-10-04', '2026-10-05', [mois]).estDisponible, isTrue);

      final annee = tache('2026-12-30', '2027-01-02');
      expect(verifier('2027-01-02', '2027-01-03', [annee]).conflit, annee);
      expect(verifier('2027-01-03', '2027-01-04', [annee]).estDisponible, isTrue);
    });
  });

  group('Statut', () {
    test('une tâche terminée ne bloque jamais', () {
      final t = tache('2026-03-10', '2026-03-20', statut: StatutTache.terminee);
      expect(verifier('2026-03-10', '2026-03-20', [t]).estDisponible, isTrue);
    });

    test('à faire et en cours bloquent', () {
      for (final s in [StatutTache.aFaire, StatutTache.enCours]) {
        final t = tache('2026-03-10', '2026-03-20', statut: s);
        expect(verifier('2026-03-10', '2026-03-20', [t]).conflit, t);
      }
    });

    test('une terminée ne masque pas une vraie collision', () {
      final finie = tache('2026-03-01', '2026-03-05', statut: StatutTache.terminee);
      final active = tache('2026-03-04', '2026-03-08');
      expect(verifier('2026-03-02', '2026-03-06', [finie, active]).conflit, active);
    });
  });

  group('Tâche en cours de modification', () {
    test('n\'entre pas en conflit avec elle-même', () {
      final t = tache('2026-03-10', '2026-03-20', id: 5);
      expect(verifier('2026-03-10', '2026-03-20', [t], ignoree: 5).estDisponible,
          isTrue);
    });

    test('n\'ignore que cette tâche-là', () {
      final elleMeme = tache('2026-03-10', '2026-03-20', id: 5);
      final autre = tache('2026-03-15', '2026-03-25', id: 6);
      expect(
          verifier('2026-03-10', '2026-03-20', [elleMeme, autre], ignoree: 5).conflit,
          autre);
    });

    test('sans identifiant à ignorer, rien n\'est ignoré', () {
      final sansId = tache('2026-03-10', '2026-03-20');
      expect(verifier('2026-03-10', '2026-03-20', [sansId]).conflit, sansId);
    });
  });

  group('disponible = false', () {
    test('indisponible même sans aucune tâche', () {
      final r = verifier('2026-03-10', '2026-03-20', [], disponible: false);
      expect(r.estDisponible, isFalse);
      expect(r.personneDisponible, isFalse);
      expect(r.conflit, isNull);
    });

    test('la valeur par défaut est disponible', () {
      final r = verifierDisponibilite(
          dateDebut: '2026-03-10', dateFin: '2026-03-20', tachesDeLaPersonne: []);
      expect(r.estDisponible, isTrue);
    });
  });

  test('plusieurs conflits : renvoie toujours le plus tôt', () {
    final tard = tache('2026-03-18', '2026-03-22', id: 2);
    final tot = tache('2026-03-11', '2026-03-13', id: 1);
    expect(verifier('2026-03-10', '2026-03-20', [tard, tot]).conflit, tot);
    expect(verifier('2026-03-10', '2026-03-20', [tot, tard]).conflit, tot);
  });
}
