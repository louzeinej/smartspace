import 'package:shared_preferences/shared_preferences.dart';

// Le vrai id viendra de la connexion du module utilisateurs (membre 1).
// Après la connexion, il suffit de faire
// UtilisateurCourant.id = idDeLaPersonneConnectee.
// L'outil de simulation de l'écran des événements n'est visible qu'en développement.
class UtilisateurCourant {
  // Clé utilisée pour enregistrer l'id dans le téléphone
  static const String _cle = 'utilisateur_courant_id';

  // Id de l'employé connecté (1 par défaut)
  static int id = 1;

  // Nom affiché pour un employé (l'employé courant si on ne donne pas d'id)
  static String nom([int? unId]) => 'Employé (ID ${unId ?? id})';

  // Lit l'id enregistré (à appeler une fois au démarrage de l'application)
  static Future<void> charger() async {
    final prefs = await SharedPreferences.getInstance();
    id = prefs.getInt(_cle) ?? 1;
  }

  // Change d'employé et l'enregistre pour la prochaine fois
  static Future<void> changer(int nouvelId) async {
    id = nouvelId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_cle, nouvelId);
  }
}
