import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/user_role.dart';
import '../models/projet.dart';

/// Tâche proposée par l'IA : rien n'est créé tant que l'utilisateur ne l'a
/// pas relue et enregistrée.
class SuggestionTache {
  final String titre;
  final String description;
  final int dureeJours;
  final UserRole role;

  const SuggestionTache({
    required this.titre,
    required this.description,
    required this.dureeJours,
    required this.role,
  });
}

class SuggestionException implements Exception {
  final String message;
  SuggestionException(this.message);
  @override
  String toString() => message;
}

/// Valeur ajoutée : découpage d'un projet en tâches par l'API Gemini.
///
/// La clé vient du fichier `lib/projets/config/gemini.json`, jamais versionné
/// (modèle : `gemini.example.json`), passé au lancement :
///
///     flutter run -d windows --dart-define-from-file=lib/projets/config/gemini.json
///
/// Sans clé ou sans réseau, seule cette fonction est indisponible : le reste
/// de l'application fonctionne hors ligne.
class SuggestionService {
  SuggestionService({
    http.Client? client,
    String? cleApi,
    String? modele,
    this.delai = const Duration(seconds: 30),
  })  : _client = client ?? http.Client(),
        _cle = cleApi ?? _cleConfiguree,
        _modele = modele ?? _modeleConfigure;

  static const _cleConfiguree = String.fromEnvironment('GEMINI_API_KEY');
  static const _modeleConfigure = String.fromEnvironment('GEMINI_MODEL',
      defaultValue: 'gemini-3.5-flash-lite');
  static const _urlApi =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static const maxSuggestions = 12;
  static const dureeMax = 90;

  final http.Client _client;
  final String _cle;
  final String _modele;
  final Duration delai;

  bool get estConfiguree => _cle.trim().isNotEmpty;

  /// Seuls le titre et la description du projet sont envoyés à Gemini.
  Future<List<SuggestionTache>> suggerer(Projet projet) async {
    if (!estConfiguree) {
      throw SuggestionException(
          'Suggestions IA indisponibles : aucune clé API Gemini n\'est configurée.');
    }
    final http.Response reponse;
    try {
      reponse = await _client
          .post(
            Uri.parse('$_urlApi/$_modele:generateContent'),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _cle.trim(),
            },
            body: jsonEncode(_requete(projet)),
          )
          .timeout(delai);
    } on TimeoutException {
      throw SuggestionException(
          'Gemini ne répond pas. Réessayez dans un instant.');
    } catch (_) {
      throw SuggestionException(
          'Pas de connexion : les suggestions IA ont besoin d\'internet.');
    }

    switch (reponse.statusCode) {
      case 200:
        return analyser(_texteDe(reponse.body));
      case 400 || 401 || 403:
        throw SuggestionException(
            'Gemini a refusé la requête (HTTP ${reponse.statusCode}) : '
            'vérifiez la clé API et le modèle configurés.');
      case 429:
        throw SuggestionException(
            'Quota Gemini dépassé. Réessayez plus tard.');
      default:
        throw SuggestionException(
            'Gemini est indisponible (HTTP ${reponse.statusCode}).');
    }
  }

  Map<String, Object?> _requete(Projet projet) {
    final roles = [for (final r in UserRole.values) r.label];
    final consigne = '''
Tu aides un chef de projet à découper un projet en tâches.
Projet : « ${projet.titre} »
Description : ${projet.description}

Propose entre 3 et 8 tâches concrètes. Pour chacune : un titre court, une
description d'une ou deux phrases, une durée estimée en jours (entier de 1 à
30), et le rôle de la personne qui doit la réaliser, choisi EXACTEMENT parmi :
${roles.join(', ')}.''';
    return {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': consigne}
          ],
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseJsonSchema': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'titre': {'type': 'string'},
              'description': {'type': 'string'},
              'dureeJours': {'type': 'integer'},
              'role': {'type': 'string', 'enum': roles},
            },
            'required': ['titre', 'description', 'dureeJours', 'role'],
          },
        },
      },
    };
  }

  /// Extrait le texte généré de l'enveloppe de réponse de Gemini.
  static String _texteDe(String corps) {
    final Object? enveloppe;
    try {
      enveloppe = jsonDecode(corps);
    } on FormatException {
      throw SuggestionException('Réponse de Gemini illisible.');
    }
    if (enveloppe is! Map) {
      throw SuggestionException('Réponse de Gemini illisible.');
    }
    final candidats = enveloppe['candidates'];
    if (candidats is! List || candidats.isEmpty) {
      final retour = enveloppe['promptFeedback'];
      final raison = retour is Map ? retour['blockReason'] : null;
      throw SuggestionException(raison == null
          ? 'Gemini n\'a renvoyé aucune suggestion.'
          : 'Gemini a bloqué la demande ($raison).');
    }
    final contenu = candidats.first is Map ? candidats.first['content'] : null;
    final parties = contenu is Map ? contenu['parts'] : null;
    if (parties is! List) {
      throw SuggestionException('Gemini n\'a renvoyé aucune suggestion.');
    }
    return parties
        .map((p) => p is Map && p['text'] is String ? p['text'] as String : '')
        .join();
  }

  /// Transforme le JSON produit par l'IA en suggestions valides.
  ///
  /// Les éléments invalides (champ manquant, durée hors bornes, rôle
  /// inconnu…) sont ignorés ; seul un JSON illisible lève une erreur.
  static List<SuggestionTache> analyser(String texte) {
    final nettoye = texte
        .trim()
        .replaceFirst(RegExp(r'^```(json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '');
    final Object? donnees;
    try {
      donnees = jsonDecode(nettoye);
    } on FormatException {
      throw SuggestionException(
          'La réponse de l\'IA n\'est pas un JSON valide. Réessayez.');
    }
    final liste = donnees is Map ? donnees['taches'] : donnees;
    if (liste is! List) {
      throw SuggestionException(
          'La réponse de l\'IA n\'a pas le format attendu. Réessayez.');
    }
    return liste
        .map(_suggestionDe)
        .whereType<SuggestionTache>()
        .take(maxSuggestions)
        .toList();
  }

  static SuggestionTache? _suggestionDe(Object? element) {
    if (element is! Map) return null;
    final titre = element['titre'];
    final description = element['description'];
    final duree = element['dureeJours'];
    final role = element['role'];
    if (titre is! String || titre.trim().isEmpty) return null;
    if (description is! String || description.trim().isEmpty) return null;
    if (duree is! num || duree != duree.roundToDouble()) return null;
    if (duree < 1 || duree > dureeMax) return null;
    if (role is! String) return null;
    final roleTrouve = _roleDe(role);
    if (roleTrouve == null) return null;
    return SuggestionTache(
      titre: titre.trim(),
      description: description.trim(),
      dureeJours: duree.toInt(),
      role: roleTrouve,
    );
  }

  /// Libellé exact (« UI/UX Designer ») ou nom de l'énumération, sans tenir
  /// compte de la casse ni des espaces autour.
  static UserRole? _roleDe(String valeur) {
    final v = valeur.trim().toLowerCase();
    for (final r in UserRole.values) {
      if (r.label.toLowerCase() == v || r.name.toLowerCase() == v) return r;
    }
    return null;
  }
}
