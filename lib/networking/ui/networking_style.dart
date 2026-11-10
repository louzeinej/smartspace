import 'package:flutter/material.dart';

/// Charte graphique SmartSpace réutilisée pour le module Networking.
class SsColors {
  static const primaire = Color(0xFF7F5AF0);
  static const secondaire = Color(0xFF2D2A4A);
  static const fond = Color(0xFFF7F7FB);
  static const succes = Color(0xFF2ECC71);
  static const alerte = Color(0xFFFF6B6B);
}

class SsText {
  static const titreEcran =
      TextStyle(fontSize: 21, fontWeight: FontWeight.w500, color: SsColors.secondaire);
  static const titreCarte =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: SsColors.secondaire);
  static const courant = TextStyle(fontSize: 14, fontWeight: FontWeight.w400);
  static const secondaire =
      TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: SsColors.secondaire);
}

/// Helper pour afficher une date ISO en format lisible (ex: 01/10/2026 à 14:30).
String formatRelativeOrDate(String isoString) {
  try {
    final dt = DateTime.parse(isoString);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return "À l'instant";
    } else if (diff.inMinutes < 60) {
      return "Il y a ${diff.inMinutes} min";
    } else if (diff.inHours < 24) {
      return "Il y a ${diff.inHours} h";
    } else if (diff.inDays < 7) {
      return "Il y a ${diff.inDays} j";
    } else {
      final j = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final a = dt.year;
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return "$j/$m/$a $h:$min";
    }
  } catch (_) {
    return isoString;
  }
}
