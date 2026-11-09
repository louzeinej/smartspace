import 'dart:convert';

import 'package:http/http.dart' as http;

/// ENVOI RÉEL D'OTP PAR EMAIL (valeur ajoutée) via l'API Brevo
/// (ex-Sendinblue) — offre gratuite : 300 emails/jour, sans carte
/// bancaire : https://app.brevo.com  →  SMTP & API → Clés API.
///
/// ⚙️ MODE D'EMPLOI :
///  1. Crée un compte Brevo et génère une clé API ;
///  2. Colle-la dans [apiKey] ci-dessous ;
///  3. C'est tout : les codes de réinitialisation partiront par vrai
///     email. Sans clé (chaîne vide), l'app reste en mode « email
///     simulé » (démo soutenance).
///
/// 🔒 NOTE SÉCURITÉ (à citer en soutenance) : embarquer une clé API
/// dans une app mobile n'est acceptable que pour un projet pédagogique.
/// En production, l'envoi passerait par un petit backend qui détient
/// la clé — l'app ne devrait jamais contenir de secret.
abstract final class EmailOtpService {
  /// Colle ta clé API Brevo ici (v3), ex. 'xkeysib-abc123...'
  static const String apiKey = '';

  static const String _endpoint = 'https://api.brevo.com/v3/smtp/email';
  static const String _senderName = 'SmartSpace';
  static const String _senderEmail = 'no-reply@smartspace.tn';

  /// Vrai si une clé est configurée → l'app enverra de vrais emails.
  static bool get isConfigured => apiKey.startsWith('xkeysib-');

  /// Envoie le code OTP à [toEmail]. Retourne true si l'email est parti.
  /// En cas d'échec (réseau, quota, clé invalide), retourne false →
  /// l'app retombera sur l'email simulé.
  static Future<bool> sendOtp({
    required String toEmail,
    required String toName,
    required String code,
  }) async {
    if (!isConfigured) return false;
    try {
      final res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'api-key': apiKey,
              'content-type': 'application/json',
              'accept': 'application/json',
            },
            body: jsonEncode({
              'sender': {'name': _senderName, 'email': _senderEmail},
              'to': [
                {'email': toEmail, 'name': toName},
              ],
              'subject': 'SmartSpace — votre code de réinitialisation',
              'textContent':
                  'Bonjour $toName,\n\n'
                  'Votre code de réinitialisation SmartSpace est : $code\n\n'
                  'Il est valable 10 minutes. Si vous n\'êtes pas à '
                  'l\'origine de cette demande, ignorez ce message.\n\n'
                  '— L\'équipe SmartSpace',
            }),
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (_) {
      return false; // réseau/quota → fallback simulation
    }
  }
}
