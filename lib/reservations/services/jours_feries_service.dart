import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../../core/database_helper.dart';

/// Valeur ajoutée : consommation d'un web service externe.
///
/// Les jours fériés tunisiens viennent de l'API REST publique Nager.Date
/// (https://date.nager.at, gratuite, sans clé). Ils sont mis en cache dans la
/// table SQLite `jours_feries` : une fois une année téléchargée, l'application
/// fonctionne hors ligne (exigence du cahier des charges).
class JoursFeriesService {
  JoursFeriesService({Future<Database>? database, http.Client? client})
      : _database = database ?? DatabaseHelper.instance.database,
        _client = client ?? http.Client();

  static const _pays = 'TN';
  static const _urlApi = 'https://date.nager.at/api/v3/PublicHolidays';

  final Future<Database> _database;
  final http.Client _client;

  /// Noms français des jours fériés renvoyés en anglais par l'API.
  static const _traductions = {
    "New Year's Day": "Jour de l'an",
    'Revolution and Youth Day': 'Fête de la Révolution et de la Jeunesse',
    'Revolution Day': 'Fête de la Révolution',
    'Independence Day': "Fête de l'Indépendance",
    "Martyrs' Day": 'Journée des Martyrs',
    'Labour Day': 'Fête du Travail',
    'Republic Day': 'Fête de la République',
    "Women's Day": 'Fête de la Femme',
    'Evacuation Day': "Fête de l'Évacuation",
    'Eid al-Fitr': 'Aïd el-Fitr',
    'Eid al-Adha': 'Aïd el-Adha',
    'Islamic New Year': "Nouvel an de l'Hégire",
    "Prophet's Birthday": 'Mouled',
  };

  /// Nom du jour férié tombant le [date] (yyyy-MM-dd), ou null.
  /// Ne lève jamais d'erreur : sans internet et sans cache, renvoie null.
  Future<String?> jourFerie(String date) async {
    final annee = int.parse(date.substring(0, 4));
    await _chargerAnnee(annee);
    final db = await _database;
    final rows = await db.query('jours_feries',
        columns: ['nom'], where: 'date = ?', whereArgs: [date]);
    return rows.isEmpty ? null : rows.first['nom'] as String;
  }

  /// Télécharge les jours fériés de [annee] si l'année n'est pas déjà en cache.
  Future<void> _chargerAnnee(int annee) async {
    final db = await _database;
    final deja = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM jours_feries WHERE annee = ?', [annee])) ??
        0;
    if (deja > 0) return;
    try {
      final rep = await _client
          .get(Uri.parse('$_urlApi/$annee/$_pays'))
          .timeout(const Duration(seconds: 8));
      if (rep.statusCode != 200) return;
      final liste = jsonDecode(rep.body) as List<dynamic>;
      final batch = db.batch();
      for (final j in liste.cast<Map<String, dynamic>>()) {
        final nomEn = j['name'] as String;
        batch.insert(
          'jours_feries',
          {'date': j['date'], 'nom': _traductions[nomEn] ?? nomEn, 'annee': annee},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (_) {
      // Pas de connexion : on continue sans l'information (mode hors ligne).
    }
  }
}
