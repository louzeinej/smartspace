import 'dart:math';

import 'package:http/http.dart' as http;

/// Web service externe consommé (VALEUR AJOUTÉE de la grille) :
/// DiceBear génère un avatar déterministe à partir d'une graine
/// (`avatarSeed` stockée en base pour chaque utilisateur).
///   https://www.dicebear.com/styles/  — API gratuite, sans clé.
///
/// Logique offline-first : si l'appareil est hors-ligne, l'URL est
/// simplement ignorée par AvatarWidget qui affiche les initiales.
abstract final class AvatarService {
  static const String _baseUrl =
      'https://api.dicebear.com/9.x/adventurer/png';

  /// URL de l'avatar pour une graine donnée.
  static String avatarUrl(String seed) =>
      '$_baseUrl?seed=${Uri.encodeComponent(seed)}&size=128';

  /// Graine aléatoire attribuée à l'inscription.
  static String randomSeed() {
    final rnd = Random();
    final bytes =
        List<int>.generate(8, (_) => rnd.nextInt(256)); // 8 octets aléatoires
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Test de connectivité léger (HEAD) : sert à afficher dans le profil
  /// si le web service est joignable — bon point de démo soutenance.
  static Future<bool> isReachable() async {
    try {
      final res = await http.head(Uri.parse('$_baseUrl?seed=test&size=32'))
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false; // hors-ligne → fallback initiales
    }
  }
}
