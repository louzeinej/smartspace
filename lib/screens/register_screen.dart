import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/user_database.dart' show kSecurityQuestions;
import '../models/user_role.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import 'login_screen.dart';

/// Création de compte : nom, email, mot de passe + confirmation,
/// sélection du rôle (chips). Validation complète côté formulaire,
/// puis règles métier (email unique) côté AuthService.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  UserRole _selectedRole = UserRole.employe;
  int _securityQuestion = 0;
  final _answerCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _answerCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await context.read<AuthProvider>().register(
          fullName: _nameCtrl.text,
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          role: _selectedRole,
          securityQuestion: _securityQuestion,
          securityAnswer: _answerCtrl.text,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (res.ok) {
      // Compte créé → retour à la connexion avec message de succès.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Compte créé avec succès. Connecte-toi.'),
        backgroundColor: AppColors.success,
      ));
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()));
    } else {
      setState(() => _error = res.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Rejoins l\'espace SmartSpace',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.secondary.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Nom complet',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Le nom est obligatoire.';
                    }
                    if (v.trim().length < 3) {
                      return 'Au moins 3 caractères.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'Email professionnel',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'L\'email est obligatoire.';
                    }
                    if (!RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[a-zA-Z]{2,}$')
                        .hasMatch(v.trim())) {
                      return 'Format d\'email invalide.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    hintText: 'Mot de passe (8 caractères min.)',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 8) {
                      return 'Au moins 8 caractères.';
                    }
                    if (!RegExp(r'[A-Za-z]').hasMatch(v) ||
                        !RegExp(r'[0-9]').hasMatch(v)) {
                      return 'Doit contenir lettres ET chiffres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    hintText: 'Confirmer le mot de passe',
                    prefixIcon: Icon(Icons.lock_reset_outlined),
                  ),
                  validator: (v) => v != _passwordCtrl.text
                      ? 'Les mots de passe ne correspondent pas.'
                      : null,
                ),
                // ── Question secrète (réinitialisation du mot de passe) ──
                const SizedBox(height: 22),
                const Text('Question secrète',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  "Sert à réinitialiser ton mot de passe si tu l'oublies "
                  "(l'application fonctionne hors-ligne, sans email).",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondary.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _securityQuestion,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.help_outline_rounded),
                  ),
                  items: [
                    for (var i = 0; i < kSecurityQuestions.length; i++)
                      DropdownMenuItem(
                          value: i, child: Text(kSecurityQuestions[i])),
                  ],
                  onChanged: (v) =>
                      setState(() => _securityQuestion = v ?? 0),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _answerCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Votre réponse à la question secrète',
                    prefixIcon: Icon(Icons.question_answer_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Réponse obligatoire (2 caractères min.).'
                      : null,
                ),

                const SizedBox(height: 22),

                // ── Sélection du rôle ──
                const Text('Rôle dans l\'équipe',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  "Le rôle détermine les tâches qui peuvent t'être confiées. "
                  'Le rôle Administrateur est attribué uniquement par un '
                  'Administrateur.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondary.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Le rôle Administrateur est volontairement absent :
                    // il s'obtient par promotion, jamais à l'inscription.
                    for (final role in UserRole.values)
                      if (role != UserRole.administrateur)
                        ChoiceChip(
                        label: Text(role.label),
                        selected: _selectedRole == role,
                        onSelected: (_) =>
                            setState(() => _selectedRole = role),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: _selectedRole == role
                              ? Colors.white
                              : AppColors.secondary,
                        ),
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: _selectedRole == role
                              ? AppColors.primary
                              : const Color(0xFFD9D9E3),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 26),

                if (_error != null) ...[
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
                  const SizedBox(height: 16),
                ],
                GradientButton(
                  label: 'Créer mon compte',
                  icon: Icons.person_add_rounded,
                  loading: _loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
