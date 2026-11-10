import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartspace/models/user_role.dart';
import 'package:smartspace/projets/models/projet.dart';
import 'package:smartspace/projets/services/suggestion_service.dart';

const projet = Projet(
  titre: 'Site vitrine',
  description: 'Refonte du site de l\'entreprise',
  dateCreation: '2026-11-10',
);

/// Enveloppe de réponse de generateContent contenant [texte].
String enveloppe(String texte) => jsonEncode({
      'candidates': [
        {
          'content': {
            'role': 'model',
            'parts': [
              {'text': texte}
            ],
          },
          'finishReason': 'STOP',
        }
      ],
    });

String suggestionsJson(List<Object?> elements) => jsonEncode(elements);

Map<String, Object?> element({
  Object? titre = 'Charte graphique',
  Object? description = 'Définir couleurs et typographies.',
  Object? duree = 3,
  Object? role = 'UI/UX Designer',
}) =>
    {
      'titre': titre,
      'description': description,
      'dureeJours': duree,
      'role': role,
    };

void main() {
  late int appels;
  late http.Request? derniere;

  SuggestionService service(
    FutureOr<http.Response> Function(http.Request) reponse, {
    String cle = 'cle-de-test',
    Duration delai = const Duration(seconds: 30),
  }) {
    appels = 0;
    derniere = null;
    return SuggestionService(
      cleApi: cle,
      modele: 'modele-test',
      delai: delai,
      client: MockClient((req) async {
        appels++;
        derniere = req;
        return reponse(req);
      }),
    );
  }

  SuggestionService repondant(String texteGenere) =>
      service((_) => http.Response(enveloppe(texteGenere), 200));

  Future<SuggestionException> erreurDe(Future<Object?> appel) async {
    try {
      await appel;
    } on SuggestionException catch (e) {
      return e;
    }
    fail('une SuggestionException était attendue');
  }

  group('Réponse valide', () {
    test('analyse les tâches et envoie la bonne requête', () async {
      final s = repondant(suggestionsJson([
        element(),
        element(titre: 'API', role: 'Développeur', duree: 5),
        element(titre: 'Recette', role: 'Scrum Master', duree: 1),
      ]));

      final res = await s.suggerer(projet);

      expect(res.map((x) => x.titre), ['Charte graphique', 'API', 'Recette']);
      expect(res.map((x) => x.role), [
        UserRole.uiuxDesigner,
        UserRole.developpeur,
        UserRole.scrumMaster,
      ]);
      expect(res[1].dureeJours, 5);

      expect(appels, 1);
      expect(derniere!.url.toString(),
          'https://generativelanguage.googleapis.com/v1beta/models/modele-test:generateContent');
      expect(derniere!.headers['x-goog-api-key'], 'cle-de-test');
      expect(derniere!.url.query, isEmpty, reason: 'la clé ne va pas dans l\'URL');
      final corps = jsonDecode(derniere!.body) as Map<String, dynamic>;
      final consigne = corps['contents'][0]['parts'][0]['text'] as String;
      expect(consigne, contains('Site vitrine'));
      expect(consigne, contains('Refonte du site'));
      final config = corps['generationConfig'] as Map<String, dynamic>;
      expect(config['responseMimeType'], 'application/json');
      expect(
          config['responseJsonSchema']['items']['properties']['role']['enum'],
          [for (final r in UserRole.values) r.label]);
    });

    test('accepte un objet {"taches": [...]} et un bloc ```json', () {
      final dansObjet = jsonEncode({'taches': [element()]});
      expect(SuggestionService.analyser(dansObjet), hasLength(1));
      expect(
          SuggestionService.analyser(
              '```json\n${suggestionsJson([element()])}\n```'),
          hasLength(1));
    });

    test('texte réparti sur plusieurs parties : recollé', () async {
      final json = suggestionsJson([element()]);
      final s = service((_) => http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': json.substring(0, 10)},
                    {'text': json.substring(10)},
                  ]
                }
              }
            ]
          }),
          200));
      expect(await s.suggerer(projet), hasLength(1));
    });

    test('nettoie les espaces, accepte le nom de l\'énumération', () {
      final res = SuggestionService.analyser(suggestionsJson([
        element(titre: '  Logo  ', role: '  ui/ux designer '),
        element(titre: 'Code', role: 'developpeur'),
      ]));
      expect(res.first.titre, 'Logo');
      expect(res.map((x) => x.role),
          [UserRole.uiuxDesigner, UserRole.developpeur]);
    });

    test('au plus 12 suggestions', () {
      final res = SuggestionService.analyser(
          suggestionsJson(List.generate(20, (i) => element(titre: 'T$i'))));
      expect(res, hasLength(SuggestionService.maxSuggestions));
      expect(res.last.titre, 'T11');
    });
  });

  group('JSON malformé', () {
    test('texte généré qui n\'est pas du JSON', () async {
      final e = await erreurDe(repondant('Voici vos tâches : 1. Logo').suggerer(projet));
      expect(e.message, contains('JSON'));
    });

    test('JSON tronqué', () async {
      await erreurDe(repondant('[{"titre": "Logo", "descr').suggerer(projet));
    });

    test('JSON valide mais ni liste ni {"taches": [...]}', () async {
      await erreurDe(repondant('{"resultat": "ok"}').suggerer(projet));
      await erreurDe(repondant('"juste une chaîne"').suggerer(projet));
    });

    test('enveloppe HTML au lieu de JSON', () async {
      final s = service((_) => http.Response('<html>erreur</html>', 200));
      await erreurDe(s.suggerer(projet));
    });

    test('enveloppe sans candidats ni texte', () async {
      for (final corps in ['{}', '{"candidates": []}', '[]',
          '{"candidates": [{"content": {}}]}']) {
        final s = service((_) => http.Response(corps, 200));
        await erreurDe(s.suggerer(projet));
      }
    });

    test('demande bloquée : la raison est donnée', () async {
      final s = service((_) => http.Response(
          '{"promptFeedback": {"blockReason": "SAFETY"}}', 200));
      expect((await erreurDe(s.suggerer(projet))).message, contains('SAFETY'));
    });
  });

  group('Éléments invalides ignorés', () {
    test('rôle inconnu', () {
      final res = SuggestionService.analyser(suggestionsJson([
        element(titre: 'Garder'),
        element(titre: 'Chef de projet', role: 'Chef de projet'),
        element(titre: 'Vide', role: ''),
        element(titre: 'Nombre', role: 3),
      ]));
      expect(res.map((x) => x.titre), ['Garder']);
    });

    test('champs manquants, vides ou du mauvais type', () {
      final res = SuggestionService.analyser(suggestionsJson([
        element(titre: ''),
        element(titre: '   '),
        element(titre: null),
        element(description: ''),
        element(description: 42),
        'pas un objet',
        null,
        [1, 2],
        element(titre: 'Valide'),
      ]));
      expect(res.map((x) => x.titre), ['Valide']);
    });

    test('durée hors bornes ou non entière', () {
      final res = SuggestionService.analyser(suggestionsJson([
        element(titre: 'zéro', duree: 0),
        element(titre: 'négative', duree: -2),
        element(titre: 'trop longue', duree: 91),
        element(titre: 'décimale', duree: 2.5),
        element(titre: 'texte', duree: 'trois'),
        element(titre: 'un', duree: 1),
        element(titre: 'max', duree: 90),
        element(titre: 'entier écrit 4.0', duree: 4.0),
      ]));
      expect(res.map((x) => x.titre), ['un', 'max', 'entier écrit 4.0']);
      expect(res.last.dureeJours, 4);
    });
  });

  test('liste vide : aucune suggestion, sans erreur', () async {
    expect(await repondant('[]').suggerer(projet), isEmpty);
  });

  group('Erreurs réseau et HTTP', () {
    test('pas de connexion', () async {
      final s = service((_) => throw http.ClientException('Connexion refusée'));
      expect((await erreurDe(s.suggerer(projet))).message,
          contains('connexion'));
    });

    test('délai dépassé', () async {
      final s = service((_) => Completer<http.Response>().future,
          delai: const Duration(milliseconds: 20));
      expect((await erreurDe(s.suggerer(projet))).message,
          contains('ne répond pas'));
    });

    test('clé refusée (400, 401, 403)', () async {
      for (final code in [400, 401, 403]) {
        final s = service((_) => http.Response('{"error": {}}', code));
        expect((await erreurDe(s.suggerer(projet))).message,
            contains('clé API'));
      }
    });

    test('quota dépassé (429) et panne serveur (500)', () async {
      expect(
          (await erreurDe(service((_) => http.Response('', 429))
                  .suggerer(projet)))
              .message,
          contains('Quota'));
      expect(
          (await erreurDe(service((_) => http.Response('', 500))
                  .suggerer(projet)))
              .message,
          contains('HTTP 500'));
    });
  });

  group('Clé absente', () {
    test('aucun appel réseau, message clair', () async {
      final s = service((_) => http.Response(enveloppe('[]'), 200), cle: '');
      expect(s.estConfiguree, isFalse);
      expect((await erreurDe(s.suggerer(projet))).message,
          contains('aucune clé'));
      expect(appels, 0);
    });

    test('une clé faite d\'espaces compte comme absente', () async {
      final s = service((_) => http.Response(enveloppe('[]'), 200), cle: '   ');
      expect(s.estConfiguree, isFalse);
      await erreurDe(s.suggerer(projet));
      expect(appels, 0);
    });

    test('sans --dart-define, la clé par défaut est vide', () {
      expect(SuggestionService().estConfiguree, isFalse);
    });
  });
}
