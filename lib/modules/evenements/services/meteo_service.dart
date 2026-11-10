import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Météo prévue pour un jour donné
class MeteoPrevue {
  final double temperatureMin;
  final double temperatureMax;
  // Probabilité de pluie en % (null si l'information n'est pas fournie)
  final int? probabilitePluie;
  // Code météo officiel (WMO)
  final int codeMeteo;

  MeteoPrevue({
    required this.temperatureMin,
    required this.temperatureMax,
    required this.probabilitePluie,
    required this.codeMeteo,
  });
}

// Libellé français et icône associés à un code météo
class DescriptionMeteo {
  final String libelle;
  final IconData icone;

  const DescriptionMeteo(this.libelle, this.icone);
}

// Transforme un code météo (WMO) en libellé et en icône
DescriptionMeteo decrireMeteo(int code) {
  if (code == 0) return const DescriptionMeteo('Ensoleillé', Icons.wb_sunny);
  if (code >= 1 && code <= 3) {
    return const DescriptionMeteo('Nuageux', Icons.cloud);
  }
  if (code >= 45 && code <= 48) {
    return const DescriptionMeteo('Brouillard', Icons.foggy);
  }
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
    return const DescriptionMeteo('Pluie', Icons.grain);
  }
  if (code >= 71 && code <= 77) {
    return const DescriptionMeteo('Neige', Icons.ac_unit);
  }
  if (code >= 95 && code <= 99) {
    return const DescriptionMeteo('Orage', Icons.thunderstorm);
  }
  return const DescriptionMeteo('Variable', Icons.cloud_queue);
}

// Météo d'un lieu, avec l'API gratuite Open-Meteo (sans clé)
class MeteoService {
  // Temps maximum d'attente pour chaque appel
  static const Duration _delai = Duration(seconds: 8);

  // Renvoie la météo prévue, ou null si elle n'est pas disponible
  // (lieu inconnu, date hors prévisions, pas de réseau...).
  // Cette méthode ne lance jamais d'exception.
  Future<MeteoPrevue?> lireMeteo(String lieu, String dateEvenement) async {
    try {
      // La date doit être entre aujourd'hui et dans 15 jours
      final date = DateTime.tryParse(dateEvenement);
      if (date == null) return null;
      final maintenant = DateTime.now();
      final aujourdhui =
          DateTime.utc(maintenant.year, maintenant.month, maintenant.day);
      final jourEvenement = DateTime.utc(date.year, date.month, date.day);
      final ecart = jourEvenement.difference(aujourdhui).inDays;
      if (ecart < 0 || ecart > 15) return null;

      // Étape 1 : trouver la latitude et la longitude du lieu
      final urlLieu = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': lieu,
        'count': '1',
        'language': 'fr',
      });
      final reponseLieu = await http.get(urlLieu).timeout(_delai);
      if (reponseLieu.statusCode != 200) return null;
      final resultats = jsonDecode(reponseLieu.body)['results'] as List?;
      if (resultats == null || resultats.isEmpty) return null;
      final latitude = (resultats.first['latitude'] as num).toDouble();
      final longitude = (resultats.first['longitude'] as num).toDouble();

      // Étape 2 : les prévisions de ce jour
      final jour = dateEvenement.trim();
      final urlMeteo = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min,'
            'precipitation_probability_max',
        'timezone': 'auto',
        'start_date': jour,
        'end_date': jour,
      });
      final reponseMeteo = await http.get(urlMeteo).timeout(_delai);
      if (reponseMeteo.statusCode != 200) return null;
      final quotidien = jsonDecode(reponseMeteo.body)['daily'];

      return MeteoPrevue(
        temperatureMin: (quotidien['temperature_2m_min'][0] as num).toDouble(),
        temperatureMax: (quotidien['temperature_2m_max'][0] as num).toDouble(),
        probabilitePluie:
            (quotidien['precipitation_probability_max'][0] as num?)?.round(),
        codeMeteo: (quotidien['weather_code'][0] as num).toInt(),
      );
    } catch (e) {
      // Réseau coupé, délai dépassé, réponse inattendue : pas de météo
      return null;
    }
  }
}
