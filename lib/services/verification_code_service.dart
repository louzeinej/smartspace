import 'dart:math';

import 'package:http/http.dart' as http;

/// Génération du code de réinitialisation via un WEB SERVICE externe
/// (VALEUR AJOUTÉE) : random.org fournit de vrais nombres aléatoires
/// générés à partir de bruit atmosphérique — meilleure entropie qu'un
/// `Random()` local.
///
///   https://www.random.org/clients/http/  — API gratuite, sans clé.
///
/// Logique offline-first : si l'appareil est hors-ligne, on retombe
/// sur un générateur local pour que la fonctionnalité reste utilisable.
abstract final class VerificationCodeService {
  static const _url =
      'https://www.random.org/integers/?num=1&min=0&max=999999'
      '&col=1&base=10&format=plain&rnd=new';

  /// Retourne un code à 6 chiffres (avec zéros initiaux) et indique
  /// s'il provient de l'API ou du fallback local.
  static Future<({String code, bool fromApi})> generate() async {
    try {
      final res = await http.get(Uri.parse(_url))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final n = int.tryParse(res.body.trim());
        if (n != null) {
          return (code: n.toString().padLeft(6, '0'), fromApi: true);
        }
      }
    } catch (_) {
      // Hors-ligne / timeout → fallback local.
    }
    final n = Random().nextInt(1000000);
    return (code: n.toString().padLeft(6, '0'), fromApi: false);
  }
}
