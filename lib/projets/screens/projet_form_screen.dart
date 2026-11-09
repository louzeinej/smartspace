import 'package:flutter/material.dart';

import '../../reservations/ui/smartspace_style.dart';
import '../models/projet.dart';
import '../services/projet_service.dart';
import '../ui/projet_widgets.dart';

/// Création ou modification d'un projet.
class ProjetFormScreen extends StatefulWidget {
  const ProjetFormScreen({super.key, required this.service, this.projet});
  final ProjetService service;
  final Projet? projet;

  @override
  State<ProjetFormScreen> createState() => _ProjetFormScreenState();
}

class _ProjetFormScreenState extends State<ProjetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _titre = TextEditingController(text: widget.projet?.titre);
  late final _description =
      TextEditingController(text: widget.projet?.description);
  bool _enCours = false;

  bool get _modification => widget.projet != null;

  @override
  void dispose() {
    _titre.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enCours = true);
    final projet = Projet(
      id: widget.projet?.id,
      titre: _titre.text.trim(),
      description: _description.text.trim(),
      dateCreation: widget.projet?.dateCreation ?? formatDate(DateTime.now()),
      createurId: widget.projet?.createurId,
    );
    try {
      if (_modification) {
        await widget.service.modifierProjet(projet);
      } else {
        await widget.service.creerProjet(projet);
      }
      if (!mounted) return;
      ssMessage(context, _modification ? 'Projet modifié' : 'Projet créé');
      Navigator.pop(context);
    } on ProjetException catch (e) {
      if (mounted) ssMessage(context, e.message, erreur: true);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SsColors.fond,
      appBar:
          projetAppBar(_modification ? 'Modifier le projet' : 'Nouveau projet'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titre,
              decoration: ssChamp('Titre', icone: Icons.title),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Le titre est obligatoire'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 6,
              decoration: ssChamp('Description', icone: Icons.notes),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'La description est obligatoire'
                  : null,
            ),
            const SizedBox(height: 24),
            SsBoutonPrincipal(
              label: _enCours ? 'Enregistrement…' : 'Enregistrer',
              onPressed: _enCours ? null : _enregistrer,
            ),
          ],
        ),
      ),
    );
  }
}
