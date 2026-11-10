import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// ENVOI RÉEL D'OTP PAR EMAIL — deux fournisseurs au choix :
///
/// 🅰 GMAIL SMTP (le plus simple si tu as un compte Gmail) :
///    1. Active la validation en 2 étapes sur ton compte Google ;
///    2. https://myaccount.google.com/apppasswords → génère un
///       « mot de passe d'application » (16 caractères) ;
///    3. Colle ton adresse dans [gmailUser] et le mot de passe
///       d'application dans [gmailAppPassword].
///    ⚠️ Le mot de passe normal Gmail NE FONCTIONNE PAS (Google
///    bloque les connexions SMTP non OAuth) — il FAUT un mot de
///    passe d'application.
///
/// 🅱 BREVO (API REST, 300 emails/jour gratuits) : colle ta clé
///    `xkeysib-...` dans [brevoApiKey].
///
/// Sans aucune configuration → mode « email simulé » (démo).
///
/// 🔒 NOTE SÉCURITÉ (soutenance) : embarquer des identifiants SMTP
/// dans une app mobile n'est acceptable qu'en projet pédagogique ;
/// en production, l'envoi passerait par un backend détenant les
/// secrets.
abstract final class EmailOtpService {
  // ── Configuration Gmail SMTP ──────────────────────────────────────
  static const String gmailUser = 'youssefzarga33@gmail.com';
  static const String gmailAppPassword = 'htto diib skna bagw'; // ⚠️ révoquer après la soutenance

  // ── Configuration Brevo (API) ─────────────────────────────────────
  static const String brevoApiKey = ''; // ex. 'xkeysib-abc123...'

  static bool get _gmailConfigured =>
      gmailUser.contains('@') && gmailAppPassword.isNotEmpty;
  static bool get _brevoConfigured => brevoApiKey.startsWith('xkeysib-');

  /// Vrai si au moins un fournisseur est configuré.
  static bool get isConfigured => _gmailConfigured || _brevoConfigured;

  /// Envoie le code OTP à [toEmail]. Retourne true si l'email est parti.
  /// En cas d'échec (réseau, auth), retourne false → l'app retombera
  /// sur l'email simulé.
  static Future<bool> sendOtp({
    required String toEmail,
    required String toName,
    required String code,
  }) async {
    try {
      // Gmail prioritaire s'il est configuré, sinon Brevo.
      if (_gmailConfigured) {
        return await _sendViaGmail(toEmail, toName, code);
      }
      if (_brevoConfigured) {
        return await _sendViaBrevo(toEmail, toName, code);
      }
      return false;
    } catch (_) {
      return false; // réseau/auth → fallback simulation
    }
  }

  static String _emailBody(String toName, String code) =>
      'Bonjour $toName,\n\n'
      'Votre code de réinitialisation SmartSpace est : $code\n\n'
      'Il est valable 10 minutes. Si vous n\'êtes pas à l\'origine de '
      'cette demande, ignorez ce message.\n\n'
      '— L\'équipe SmartSpace';

  static const String _subject =
      'SmartSpace — votre code de réinitialisation';

  // ── Gmail SMTP (smtp.gmail.com:465, mot de passe d'application) ──
  static Future<bool> _sendViaGmail(String toEmail, String toName, String code) async {
    final smtp = SmtpServer(
      'smtp.gmail.com',
      port: 465,
      ssl: true,
      username: gmailUser,
      password: gmailAppPassword,
    );
    final message = Message()
      ..from = Address(gmailUser, 'SmartSpace')
      ..recipients.add(toEmail)
      ..subject = _subject
      ..text = _emailBody(toName, code);
    // send() lève une exception en cas d'échec SMTP ; si elle ne
    // lève pas, le message est parti.
    await send(message, smtp);
    return true;
  }

  // ── Brevo (API REST) ─────────────────────────────────────────────
  static Future<bool> _sendViaBrevo(String toEmail, String toName, String code) async {
    final res = await http
        .post(
          Uri.parse('https://api.brevo.com/v3/smtp/email'),
          headers: {
            'api-key': brevoApiKey,
            'content-type': 'application/json',
            'accept': 'application/json',
          },
          body:
              '{"sender":{"name":"SmartSpace","email":"$gmailUser"},'
              '"to":[{"email":"$toEmail","name":"$toName"}],'
              '"subject":"$_subject",'
              '"textContent":"${_emailBody(toName, code).replaceAll('\n', '\\n')}"',
        )
        .timeout(const Duration(seconds: 8));
    return res.statusCode == 201 || res.statusCode == 200;
  }
}
