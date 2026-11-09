import 'package:flutter/material.dart';

import '../models/user_role.dart';

/// Badge de statut « pilule » (charte §8.3) affichant le rôle.
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role, this.small = false});

  final UserRole role;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 12,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: role.badgeColor,
        borderRadius: BorderRadius.circular(50), // forme pilule
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(role.icon, size: small ? 12 : 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            role.label,
            style: TextStyle(
              fontSize: small ? 10 : 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
