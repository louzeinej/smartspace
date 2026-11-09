import 'user_role.dart';

/// Modèle Utilisateur — table `users` (module Gestion des Utilisateurs).
///
/// Le mot de passe n'est JAMAIS stocké en clair : seule son empreinte
/// SHA-256 est persistée (voir AuthService).
class User {
  User({
    this.id,
    required this.fullName,
    required this.email,
    required this.passwordHash,
    required this.role,
    required this.avatarSeed,
    required this.createdAt,
    this.securityQuestion = -1,
    this.securityAnswerHash = '',
    this.phone = '',
  });

  final int? id;
  String fullName;
  String email; // unique en base (index)
  final String passwordHash; // SHA-256 hexadécimal
  UserRole role;
  final String avatarSeed; // graine pour l'API DiceBear (valeur ajoutée)
  final DateTime createdAt;

  /// Question secrète (index dans kSecurityQuestions, -1 = aucune) et
  /// empreinte SHA-256 de la réponse — utilisées par « Mot de passe
  /// oublié » (application offline : pas d'email possible).
  final int securityQuestion;
  final String securityAnswerHash;

  /// Numéro de téléphone (optionnel) — canal alternatif pour la
  /// réinitialisation du mot de passe.
  final String phone;

  /// Sérialisation vers la base SQLite.
  Map<String, Object?> toMap() => {
        'id': id,
        'fullName': fullName,
        'email': email.toLowerCase().trim(),
        'passwordHash': passwordHash,
        'roleIndex': role.index,
        'avatarSeed': avatarSeed,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'securityQuestion': securityQuestion,
        'securityAnswerHash': securityAnswerHash,
        'phone': phone,
      };

  /// Désérialisation depuis une ligne SQLite.
  factory User.fromMap(Map<String, Object?> map) => User(
        id: map['id'] as int?,
        fullName: map['fullName'] as String,
        email: map['email'] as String,
        passwordHash: map['passwordHash'] as String,
        role: UserRole.fromIndex(map['roleIndex'] as int),
        avatarSeed: map['avatarSeed'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        securityQuestion:
            (map['securityQuestion'] as int?) ?? -1,
        securityAnswerHash:
            (map['securityAnswerHash'] as String?) ?? '',
        phone: (map['phone'] as String?) ?? '',
      );

  /// Initiales affichées quand l'avatar distant n'est pas disponible
  /// (mode hors-ligne → fallback offline-first).
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Copie modifiée (utile pour l'édition sans muter l'objet affiché).
  User copyWith({
    String? fullName,
    String? email,
    UserRole? role,
    String? passwordHash,
  }) =>
      User(
        id: id,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        passwordHash: passwordHash ?? this.passwordHash,
        role: role ?? this.role,
        avatarSeed: avatarSeed,
        createdAt: createdAt,
      );
}
