import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/avatar_service.dart';
import '../theme/app_theme.dart';

/// Avatar utilisateur alimenté par le web service DiceBear (valeur
/// ajoutée). Fallback offline-first : initiales sur fond dégradé si
/// l'image distante n'est pas disponible (pas de connexion / erreur).
class AvatarWidget extends StatelessWidget {
  const AvatarWidget({super.key, required this.user, this.size = 48});

  final User user;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2.5),
      child: Image.network(
        AvatarService.avatarUrl(user.avatarSeed),
        width: size,
        height: size,
        fit: BoxFit.cover,
        // En attente du réseau → initiales immédiatement visibles.
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _fallback(),
        // Hors-ligne ou erreur → initiales (jamais d'écran cassé).
        errorBuilder: (_, _, _) => _fallback(),
      ),
    );
  }

  Widget _fallback() => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        alignment: Alignment.center,
        child: Text(
          user.initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: size * 0.36,
          ),
        ),
      );
}
