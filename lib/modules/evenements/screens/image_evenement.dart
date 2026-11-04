import 'dart:io';

import 'package:flutter/material.dart';

// Affiche la photo d'un événement, quelle que soit son origine :
// - une photo d'exemple rangée dans assets/ -> Image.asset
// - une photo importée depuis la galerie (fichier du téléphone) -> Image.file
// - pas de photo du tout -> un bloc violet avec une icône
class ImageEvenement extends StatelessWidget {
  final String? image;
  final double height;

  const ImageEvenement({super.key, required this.image, this.height = 140});

  @override
  Widget build(BuildContext context) {
    // Bloc violet affiché quand il n'y a pas de photo
    final remplacement = Container(
      height: height,
      width: double.infinity,
      color: const Color(0xFF7F5AF0).withValues(alpha: 0.15),
      child: const Center(
        child: Icon(Icons.event, size: 48, color: Color(0xFF7F5AF0)),
      ),
    );

    final chemin = image;
    if (chemin == null || chemin.isEmpty) {
      return remplacement;
    }

    // Bloc affiché si la photo n'arrive pas à se charger
    Widget erreur(BuildContext context, Object error, StackTrace? stackTrace) {
      return Container(
        height: height,
        width: double.infinity,
        color: Colors.grey[300],
        child: const Center(child: Icon(Icons.broken_image, size: 48)),
      );
    }

    // Chemin qui commence par "assets/" : photo d'exemple
    if (chemin.startsWith('assets/')) {
      return Image.asset(
        chemin,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: erreur,
      );
    }

    // Juste un nom de fichier (ex : "fete.jpg") : ancien format des
    // événements d'exemple, la photo est dans assets/images/evenements/
    if (!chemin.contains('/') && !chemin.contains('\\')) {
      return Image.asset(
        'assets/images/evenements/$chemin',
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: erreur,
      );
    }

    // Sinon : photo importée, enregistrée dans le dossier de l'application
    return Image.file(
      File(chemin),
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: erreur,
    );
  }
}
