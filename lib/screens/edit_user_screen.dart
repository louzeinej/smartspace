import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/module_access.dart';
import '../core/session.dart';
import '../database/user_database.dart' show kSecurityQuestions;
import '../database/user_dao.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';

/// Écran trois modes :
///  - [user] == null      : CRÉATION d'un compte par un Administrateur
///                          (rôle libre, y compris Administrateur) ;
///  - [editPassword] fals : modification du profil (nom, email, rôle) ;
///  - [editPassword] true : changement de mot de passe.
class EditUserScreen extends StatefulWidget {
  const EditUserScreen({
    super.key,
    this.user,
    this.editPassword = false,
  });

  final User? user;
  final bool editPassword;

  bool get isCreate => user == null;

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.user?.fullName ?? '');
  late final TextEditingController _emailCtrl =
      TextEditingController(text: widget.user?.email ?? '');
  final _oldPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  late UserRole _role = widget.user?.role ?? UserRole.employe;
  int _securityQuestion = 0;
  final _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _oldPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmCtrl.dispose();
    _answerCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    // ── Mode CRÉATION (Administrateur) ──
    if (widget.isCreate) {
      final res = await context.read<AuthProvider>().adminCreateUser(
            fullName: _nameCtrl.text,
            email: _emailCtrl.text,
            password: _newPwdCtrl.text,
            role: _role,
            securityQuestion: _securityQuestion,
            securityAnswer: _answerCtrl.text,
            phone: _phoneCtrl.text,
          );
      if (!mounted) return;
      setState(() => _loading = false);
      if (res.ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Compte de ${_nameCtrl.text.trim()} créé.'),
          backgroundColor: AppColors.success,
        ));
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = res.message);
      }
      return;
    }

    // ── Mode MOT DE PASSE ──
    if (widget.editPassword) {
      final res = await context.read<AuthProvider>().changePassword(
            widget.user!,
            _oldPwdCtrl.text,
            _newPwdCtrl.text,
          );
      if (!mounted) return;
      setState(() => _loading = false);
      if (res.ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Mot de passe modifié.'),
          backgroundColor: AppColors.success,
        ));
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = res.message);
      }
      return;
    }

    // ── Mode PROFIL : unicité d'email vérifiée si changé. ──
    final newEmail = _emailCtrl.text.trim().toLowerCase();
    if (newEmail != widget.user!.email) {
      final clash = await UserDao.instance.findByEmail(newEmail);
      if (clash != null && clash.id != widget.user!.id) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Cet email est déjà utilisé par un autre compte.';
        });
        return;
      }
    }

    final updated = User(
      id: widget.user!.id,
      fullName: _nameCtrl.text.trim(),
      email: newEmail,
      passwordHash: widget.user!.passwordHash,
      role: _role,
      avatarSeed: widget.user!.avatarSeed,
      createdAt: widget.user!.createdAt,
      securityQuestion: widget.user!.securityQuestion,
      securityAnswerHash: widget.user!.securityAnswerHash,
    );
    await UserDao.instance.update(updated);
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Profil mis à jour.'),
      backgroundColor: AppColors.success,
    ));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isCreate
        ? 'Nouvel utilisateur'
        : widget.editPassword
            ? 'Mot de passe'
            : 'Modifier le profil';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.isCreate) ...[
                  Text(
                    'Création d\'un compte par un Administrateur : le rôle '
                    'est libre, y compris Administrateur.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondary.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                        hintText: 'Nom complet',
                        prefixIcon: Icon(Icons.person_outline_rounded)),
                    validator: (v) => (v == null || v.trim().length < 3)
                        ? 'Au moins 3 caractères.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        hintText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded)),
                    validator: (v) {
                      if (v == null ||
                          !RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[a-zA-Z]{2,}$')
                              .hasMatch(v.trim())) {
                        return 'Format d\'email invalide.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _newPwdCtrl,
                    obscureText: _obscure,
                    decoration: const InputDecoration(
                        hintText: 'Mot de passe (8 min.)',
                        prefixIcon: Icon(Icons.lock_rounded)),
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
                        prefixIcon: Icon(Icons.lock_reset_outlined)),
                    validator: (v) =>
                        v != _newPwdCtrl.text ? 'Ne correspond pas.' : null,
                  ),
                  const SizedBox(height: 18),
                ] else if (!widget.editPassword) ...[
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                        hintText: 'Nom complet',
                        prefixIcon: Icon(Icons.person_outline_rounded)),
                    validator: (v) => (v == null || v.trim().length < 3)
                        ? 'Au moins 3 caractères.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        hintText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded)),
                    validator: (v) {
                      if (v == null ||
                          !RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[a-zA-Z]{2,}$')
                              .hasMatch(v.trim())) {
                        return 'Format d\'email invalide.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                // ── RÔLE (création : libre ; édition : Administrateur seul) ──
                if (widget.isCreate || !widget.editPassword)
                  if (widget.isCreate ||
                      ModuleAccess.canManageUsers(Session.roleEnum)) ...[
                    const Text('Rôle',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final role in UserRole.values)
                          ChoiceChip(
                            label: Text(role.label),
                            selected: _role == role,
                            onSelected: (_) =>
                                setState(() => _role = role),
                            labelStyle: TextStyle(
                                fontSize: 12,
                                color: _role == role
                                    ? Colors.white
                                    : AppColors.secondary),
                            selectedColor: AppColors.primary,
                            backgroundColor: Colors.white,
                            side: BorderSide(
                                color: _role == role
                                    ? AppColors.primary
                                    : const Color(0xFFD9D9E3)),
                          ),
                      ],
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "Rôle : ${widget.user!.role.label} "
                        '(modifiable uniquement par un Administrateur)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondary.withValues(alpha: 0.55),
                        ),
                      ),
                    ),

                // ── QUESTION SECRÈTE (création uniquement) ──
                if (widget.isCreate) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: 'Téléphone (optionnel)',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final digits = v.replaceAll(RegExp(r'\D'), '');
                      return digits.length < 8
                          ? 'Au moins 8 chiffres (ou laisser vide).'
                          : null;
                    },
                  ),
                  const SizedBox(height: 18),
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
                      hintText: 'Réponse à la question secrète',
                      prefixIcon: Icon(Icons.question_answer_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Réponse obligatoire (2 caractères min.).'
                        : null,
                  ),
                ],

                // ── ANCIEN MOT DE PASSE (mode mot de passe) ──
                if (!widget.isCreate && widget.editPassword) ...[
                  TextFormField(
                    controller: _oldPwdCtrl,
                    obscureText: _obscure,
                    decoration: const InputDecoration(
                        hintText: 'Mot de passe actuel',
                        prefixIcon: Icon(Icons.lock_outline_rounded)),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Obligatoire.' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _newPwdCtrl,
                    obscureText: _obscure,
                    decoration: const InputDecoration(
                        hintText: 'Nouveau mot de passe (8 min.)',
                        prefixIcon: Icon(Icons.lock_rounded)),
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
                        hintText: 'Confirmer le nouveau mot de passe',
                        prefixIcon: Icon(Icons.lock_reset_outlined)),
                    validator: (v) =>
                        v != _newPwdCtrl.text ? 'Ne correspond pas.' : null,
                  ),
                ],
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.alert.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.alert)),
                  ),
                  const SizedBox(height: 16),
                ],
                GradientButton(
                  label: widget.isCreate ? 'Créer le compte' : 'Enregistrer',
                  icon: widget.isCreate
                      ? Icons.person_add_rounded
                      : Icons.save_rounded,
                  loading: _loading,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
