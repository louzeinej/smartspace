import 'package:flutter/material.dart';

/// Charte graphique SmartSpace (cahier des charges §8).
/// Tous les écrans du module User respectent ces constantes afin de
/// rester cohérents avec les 4 autres modules de l'application.
abstract final class AppColors {
  static const Color primary = Color(0xFF7F5AF0); // Violet primaire
  static const Color secondary = Color(0xFF2D2A4A); // Gris-violet
  static const Color background = Color(0xFFF7F7FB); // Fond des écrans
  static const Color success = Color(0xFF2ECC71); // Succès / disponibilité
  static const Color alert = Color(0xFFFF6B6B); // Alerte / erreur

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF9B7BFF), primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Typographie : Roboto (police par défaut de Flutter), 2 graisses seulement.
abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
        ).copyWith(error: AppColors.alert),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.secondary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 20, // Titre d'écran : 20-22 px, medium
            fontWeight: FontWeight.w500,
            color: AppColors.secondary,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          // Champs : fond blanc, bordure grise fine, coins arrondis 6 px
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFD9D9E3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFD9D9E3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.alert),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      );
}
