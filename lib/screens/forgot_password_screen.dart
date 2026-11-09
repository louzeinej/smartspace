import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/user_database.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';

/// « Mot de passe oublié » — application offline, donc pas d'email :
/// on vérifie la QUESTION SECRÈTE choisie à l'inscription, puis on
/// laisse l'utilisateur définir un nouveau mot de passe.
///
/// Trois étapes dans un seul écran :
///  1. email → charge la question secrète du compte ;
///  2. réponse à la question (comparaison d'empreintes SHA-256) ;
///  3. nouveau mot de passe.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  int? _questionIndex; // null = étape email non validée
  bool _loading = false;
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _answerCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  /// Étape 1 : retrouve la question secrète associée à l'email.
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

  /// Étape 2+3 : vérifie la réponse et enregistre le nouveau mot de passe.
  Future<void> _reset() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await context.read<AuthProvider>().resetPassword(
          email: _emailCtrl.text,
          answer: _answerCtrl.text,
          newPassword: _newPwdCtrl.text,
        );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.ok) {
        _done = true;
      } else {
        _error = res.message;
      }
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
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Étape 1 : email ──
          TextFormField(
            controller: _emailCtrl,
            enabled: _questionIndex == null,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Email du compte',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          if (_questionIndex == null) ...[
            const SizedBox(height: 18),
            GradientButton(
              label: 'Trouver ma question secrète',
              icon: Icons.search_rounded,
              loading: _loading,
              onPressed: _findQuestion,
            ),
          ],

          // ── Étape 2 : question + réponse ──
          if (_questionIndex != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
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
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _answerCtrl,
              decoration: const InputDecoration(
                hintText: 'Votre réponse',
                prefixIcon: Icon(Icons.question_answer_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _newPwdCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Nouveau mot de passe (8 min.)',
                prefixIcon: Icon(Icons.lock_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Confirmer le nouveau mot de passe',
                prefixIcon: Icon(Icons.lock_reset_outlined),
              ),
            ),
            const SizedBox(height: 22),
            if (_newPwdCtrl.text.isNotEmpty &&
                _newPwdCtrl.text != _confirmCtrl.text)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('Les mots de passe ne correspondent pas.',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.alert)),
              ),
            GradientButton(
              label: 'Réinitialiser mon mot de passe',
              icon: Icons.key_rounded,
              loading: _loading,
              onPressed: (_newPwdCtrl.text.length >= 8 &&
                      _newPwdCtrl.text == _confirmCtrl.text)
                  ? _reset
                  : null,
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
      ),
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
          child: const Icon(Icons.check_rounded,
              size: 44, color: Colors.white),
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
