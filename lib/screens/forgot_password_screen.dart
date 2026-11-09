import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/user_database.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';

/// « Mot de passe oublié » — deux méthodes :
///
/// 1. CODE DE VÉRIFICATION (principale, web service externe) :
///    un code à 6 chiffres est généré par l'API random.org (valeur
///    ajoutée), l'utilisateur le saisit puis définit son nouveau mot
///    de passe. En production, le code partirait par email ; en démo,
///    il s'affiche dans une boîte « simulation email ».
///
/// 2. QUESTION SECRÈTE (secours, 100 % offline) : la réponse donnée
///    à l'inscription est vérifiée par comparaison d'empreintes SHA-256.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Method { codeApi, questionSecrete }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  _Method _method = _Method.codeApi;
  int? _questionIndex; // étape question secrète validée
  bool _codeSent = false; // étape code : code généré
  bool _loading = false;
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _answerCtrl.dispose();
    _codeCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res =
        await context.read<AuthProvider>().requestResetCode(_emailCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!res.ok) {
      setState(() => _error = res.message);
      return;
    }
    setState(() => _codeSent = true);
    // Simulation de la réception de l'email contenant le code.
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📬 Email simulé'),
        content: Text(
          'Bonjour,\n\nVotre code de vérification SmartSpace est :\n\n'
          '   ${res.message}\n\n'
          '(Code valable 10 minutes — en production, il serait envoyé '
          'par le serveur mail de l\'entreprise. Il est généré par le '
          'web service random.org.)',
          textAlign: TextAlign.start,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('J\'ai compris',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _findQuestion() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final q = await context
        .read<AuthProvider>()
        .securityQuestionFor(_emailCtrl.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (q == null) {
        _error = 'Aucun compte (ou aucune question secrète) pour cet email.';
      } else {
        _questionIndex = q;
      }
    });
  }

  Future<void> _reset() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final res = _method == _Method.codeApi
        ? await auth.resetPasswordWithCode(
            identifier: _emailCtrl.text,
            code: _codeCtrl.text,
            newPassword: _newPwdCtrl.text,
          )
        : await auth.resetPassword(
            identifier: _emailCtrl.text,
            answer: _answerCtrl.text,
            newPassword: _newPwdCtrl.text,
          );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _done = res.ok;
      _error = res.ok ? null : res.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: _done ? _successCard() : _form(),
        ),
      ),
    );
  }

  Widget _form() {
    final codeReady = _method == _Method.codeApi && _codeSent;
    final questionReady =
        _method == _Method.questionSecrete && _questionIndex != null;
    final canSubmit = (codeReady || questionReady) &&
        _newPwdCtrl.text.length >= 8 &&
        _newPwdCtrl.text == _confirmCtrl.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Choix de la méthode ──
        SegmentedButton<_Method>(
          segments: const [
            ButtonSegment(
              value: _Method.codeApi,
              icon: Icon(Icons.mark_email_read_outlined, size: 18),
              label: Text('Code email', style: TextStyle(fontSize: 12)),
            ),
            ButtonSegment(
              value: _Method.questionSecrete,
              icon: Icon(Icons.help_outline_rounded, size: 18),
              label: Text('Question secrète',
                  style: TextStyle(fontSize: 12)),
            ),
          ],
          selected: {_method},
          onSelectionChanged: (s) => setState(() {
            _method = s.first;
            _error = null;
          }),
        ),
        const SizedBox(height: 20),

        // ── Étape 1 : email ──
        TextFormField(
          controller: _emailCtrl,
          enabled: !_codeSent && _questionIndex == null,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'Email ou numéro de téléphone',
            prefixIcon: Icon(Icons.alternate_email_rounded),
          ),
        ),
        if (!_codeSent && _questionIndex == null) ...[
          const SizedBox(height: 18),
          GradientButton(
            label: _method == _Method.codeApi
                ? 'Recevoir un code de vérification'
                : 'Trouver ma question secrète',
            icon: _method == _Method.codeApi
                ? Icons.send_rounded
                : Icons.search_rounded,
            loading: _loading,
            onPressed: _method == _Method.codeApi ? _sendCode : _findQuestion,
          ),
        ],

        // ── Méthode CODE API ──
        if (_codeSent) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(children: [
              Icon(Icons.cloud_done_outlined,
                  color: AppColors.primary, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Code envoyé par email/SMS (généré par l\'API random.org). '
                  'Saisissez-le ci-dessous — valable 10 minutes.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.secondary),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              hintText: 'Code à 6 chiffres',
              counterText: '',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
          ),
        ],

        // ── Méthode QUESTION SECRÈTE ──
        if (questionReady) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.help_outline_rounded,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  kSecurityQuestions[_questionIndex!],
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.secondary),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _answerCtrl,
            decoration: const InputDecoration(
              hintText: 'Votre réponse',
              prefixIcon: Icon(Icons.question_answer_outlined),
            ),
          ),
        ],

        // ── Nouveau mot de passe (commun) ──
        if (_codeSent || questionReady) ...[
          const SizedBox(height: 14),
          TextFormField(
            controller: _newPwdCtrl,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Nouveau mot de passe (8 min., lettres + chiffres)',
              prefixIcon: Icon(Icons.lock_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmCtrl,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Confirmer le nouveau mot de passe',
              prefixIcon: Icon(Icons.lock_reset_outlined),
            ),
          ),
          const SizedBox(height: 22),
          GradientButton(
            label: 'Réinitialiser mon mot de passe',
            icon: Icons.key_rounded,
            loading: _loading,
            onPressed: canSubmit ? _reset : null,
          ),
        ],

        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.alert.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.alert, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_error!,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.alert)),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _successCard() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient, shape: BoxShape.circle),
          child:
              const Icon(Icons.check_rounded, size: 44, color: Colors.white),
        ),
        const SizedBox(height: 20),
        const Text('Mot de passe réinitialisé !',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text(
          'Tu peux maintenant te connecter avec ton nouveau mot de passe.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13,
              color: AppColors.secondary.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 26),
        GradientButton(
          label: 'Retour à la connexion',
          icon: Icons.login_rounded,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
