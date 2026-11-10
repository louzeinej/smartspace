import 'package:flutter/material.dart';

import '../../models/user_role.dart';
import '../../reservations/ui/smartspace_style.dart';
import '../models/statut_tache.dart';
import '../models/tache.dart';
import '../services/projet_service.dart';
import '../ui/projet_widgets.dart';

/// Création ou modification d'une tâche d'un projet.
class TacheFormScreen extends StatefulWidget {
  const TacheFormScreen({
    super.key,
    required this.service,
    required this.projetId,
    this.tache,
  });
  final ProjetService service;
  final int projetId;
  final Tache? tache;

  @override
  State<TacheFormScreen> createState() => _TacheFormScreenState();
}

class _TacheFormScreenState extends State<TacheFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _titre = TextEditingController(text: widget.tache?.titre);
  late final _description =
      TextEditingController(text: widget.tache?.description);
  late String? _dateDebut = widget.tache?.dateDebut;
  late String? _dateFin = widget.tache?.dateFin;
  late final _debutAffiche = TextEditingController(
      text: _dateDebut == null ? '' : afficherDate(_dateDebut!));
  late final _finAffiche = TextEditingController(
      text: _dateFin == null ? '' : afficherDate(_dateFin!));
  late UserRole? _role = widget.tache?.roleRequis;
  bool _enCours = false;

  bool get _modification => widget.tache != null;

  @override
  void dispose() {
    _titre.dispose();
    _description.dispose();
    _debutAffiche.dispose();
    _finAffiche.dispose();
    super.dispose();
  }

  Future<void> _choisirDate(bool debut) async {
    final courante = debut ? _dateDebut : _dateFin;
    final d = await showDatePicker(
      context: context,
      initialDate: courante == null ? DateTime.now() : DateTime.parse(courante),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    final iso = formatDate(d);
    setState(() {
      if (debut) {
        _dateDebut = iso;
        _debutAffiche.text = afficherDate(iso);
      } else {
        _dateFin = iso;
        _finAffiche.text = afficherDate(iso);
      }
    });
  }

  String? _validerFin(String? _) {
    if (_dateFin == null) return 'La date de fin est obligatoire';
    if (_dateDebut != null && _dateFin!.compareTo(_dateDebut!) < 0) {
      return 'La date de fin ne peut pas précéder la date de début';
    }
    return null;
  }

  Future<void> _enregistrer({bool retirerAffectation = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enCours = true);
    final tache = Tache(
      id: widget.tache?.id,
      titre: _titre.text.trim(),
      description: _description.text.trim(),
      dateDebut: _dateDebut!,
      dateFin: _dateFin!,
      roleRequis: _role!,
      statut: widget.tache?.statut ?? StatutTache.aFaire,
      projetId: widget.projetId,
      utilisateurId: widget.tache?.utilisateurId,
    );
    try {
      if (_modification) {
        await widget.service
            .modifierTache(tache, retirerAffectation: retirerAffectation);
      } else {
        await widget.service.creerTache(tache);
      }
      if (!mounted) return;
      ssMessage(context, _modification ? 'Tâche modifiée' : 'Tâche créée');
      Navigator.pop(context);
    } on ConflitAffectationException catch (e) {
      if (!mounted) return;
      final retirer = await proposerRetraitAffectation(context, e);
      if (retirer && mounted) await _enregistrer(retirerAffectation: true);
    } on ProjetException catch (e) {
      if (mounted) ssMessage(context, e.message, erreur: true);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Widget _champDate(String label, TextEditingController controleur,
      String? Function(String?) validateur, VoidCallback onTap) {
    return TextFormField(
      controller: controleur,
      readOnly: true,
      onTap: onTap,
      decoration: ssChamp(label, icone: Icons.calendar_today_outlined),
      validator: validateur,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SsColors.fond,
      appBar:
          projetAppBar(_modification ? 'Modifier la tâche' : 'Nouvelle tâche'),
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
              minLines: 2,
              maxLines: 5,
              decoration: ssChamp('Description', icone: Icons.notes),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'La description est obligatoire'
                  : null,
            ),
            const SizedBox(height: 12),
            _champDate(
              'Date de début',
              _debutAffiche,
              (_) => _dateDebut == null
                  ? 'La date de début est obligatoire'
                  : null,
              () => _choisirDate(true),
            ),
            const SizedBox(height: 12),
            _champDate(
              'Date de fin',
              _finAffiche,
              _validerFin,
              () => _choisirDate(false),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<UserRole>(
              initialValue: _role,
              isExpanded: true,
              decoration: ssChamp('Rôle requis', icone: Icons.badge_outlined),
              items: [
                for (final r in UserRole.values)
                  DropdownMenuItem(value: r, child: Text(r.label)),
              ],
              onChanged: (r) => setState(() => _role = r),
              validator: (r) => r == null ? 'Le rôle est obligatoire' : null,
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
