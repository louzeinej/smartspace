/// Utilisateur connecté, partagé par tous les modules.
///
/// Provisoire : sera rempli par le module Utilisateurs (Youssef Messoudi)
/// après la connexion. En attendant, un administrateur de démo est connecté.
class Session {
  Session._();

  static int utilisateurId = 1;
  static String nom = 'Admin démo';
  static String role = 'Administrateur';

  static bool get estAdmin => role == 'Administrateur';

  static void connecter({required int id, required String nom, required String role}) {
    utilisateurId = id;
    Session.nom = nom;
    Session.role = role;
  }
}
