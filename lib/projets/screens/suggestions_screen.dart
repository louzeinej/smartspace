import 'package:flutter/material.dart';

import '../../models/user_role.dart';
import '../../reservations/ui/smartspace_style.dart';
import '../models/projet.dart';
import '../models/tache.dart';
import '../services/projet_service.dart';
import '../services/suggestion_service.dart';
import '../ui/projet_widgets.dart';

/// yyyy-MM-dd + [jours]. DateTime(a, m, j + n) plutôt qu'un Duration :
/// ajouter 24 h peut retomber la veille lors d'un changement d'heure.
String ajouterJours(String iso, int jours) {
  final d = DateTime.parse(iso);
  return formatDate(DateTime(d.year, d.month, d.day + jours));
}

/// Suggestion en cours de relecture : modifiable, cochée ou non.
class _Brouillon {
  _Brouillon(SuggestionTache s)
      : titre = TextEditingController(text: s.titre),
        description = TextEditingController(text: s.description),
        role = s.role,
        dureeJours = s.dureeJours;

  final TextEditingController titre;
  final TextEditingController description;
  final debutAffiche = TextEditingController();
  final finAffiche = TextEditingController();
  final int dureeJours;
  UserRole role;
  bool retenue = true;
  String debut = '';
  String fin = '';

  void placer(String nouveauDebut, String nouvelleFin) {
    debut = nouveauDebut;
    fin = nouvelleFin;
    debutAffiche.text = afficherDate(debut);
    finAffiche.text = afficherDate(fin);
  }

  void dispose() {
    titre.dispose();
    description.dispose();
    debutAffiche.dispose();
    finAffiche.dispose();
  }
}

/// Relecture des tâches proposées par l'IA. Rien n'est créé avant
/// « Créer » ; chaque tâche passe par [ProjetService.creerTache].
class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({
    super.key,
    required this.service,
    required this.suggestions,
    required this.projet,
  });
  final ProjetService service;
  final SuggestionService suggestions;
  final Projet projet;

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tous = <_Brouillon>[];
  late Future<List<_Brouillon>> _brouillons;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _brouillons = _charger();
  }

  @override
  void dispose() {
    for (final b in _tous) {
      b.dispose();
    }
    super.dispose();
  }

  /// Les tâches s'enchaînent à partir d'aujourd'hui, chacune sur sa durée
  /// estimée ; l'utilisateur ajuste ensuite les dates.
  Future<List<_Brouillon>> _charger() async {
    final suggestions = await widget.suggestions.suggerer(widget.projet);
    final brouillons = suggestions.map(_Brouillon.new).toList();
    var debut = formatDate(DateTime.now());
    for (final b in brouillons) {
      final fin = ajouterJours(debut, b.dureeJours - 1);
      b.placer(debut, fin);
      debut = ajouterJours(fin, 1);
    }
    _tous.addAll(brouillons);
    return brouillons;
  }

  void _reessayer() {
    setState(() {
      _brouillons = _charger();
    });
  }

  Future<void> _choisirDate(_Brouillon b, bool debut) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(debut ? b.debut : b.fin),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() {
      final iso = formatDate(d);
      if (debut) {
        b.placer(iso, b.fin);
      } else {
        b.placer(b.debut, iso);
      }
    });
  }

  Future<void> _enregistrer(List<_Brouillon> brouillons) async {
    if (!_formKey.currentState!.validate()) return;
    final retenues = brouillons.where((b) => b.retenue).toList();
    setState(() => _enCours = true);
    var creees = 0;
    try {
      for (final b in retenues) {
        await widget.service.creerTache(Tache(
          titre: b.titre.text.trim(),
          description: b.description.text.trim(),
          dateDebut: b.debut,
          dateFin: b.fin,
          roleRequis: b.role,
          projetId: widget.projet.id!,
        ));
        creees++;
        // Déjà enregistrée : elle ne sera pas recréée si l'on réessaie.
        brouillons.remove(b);
      }
      if (!mounted) return;
      ssMessage(context, '$creees tâche(s) créée(s)');
      Navigator.pop(context);
    } on ProjetException catch (e) {
      if (!mounted) return;
      ssMessage(
        context,
        creees == 0
            ? e.message
            : '$creees tâche(s) créée(s), puis échec : ${e.message}',
        erreur: true,
      );
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Widget _champDate(String label, TextEditingController controleur,
      String? Function(String?)? validateur, VoidCallback onTap) {
    return TextFormField(
      controller: controleur,
      readOnly: true,
      onTap: onTap,
      decoration: ssChamp(label, icone: Icons.calendar_today_outlined),
      validator: validateur,
    );
  }

  Widget _carte(_Brouillon b, int numero) {
    String? obligatoire(String? v, String message) =>
        b.retenue && (v == null || v.trim().isEmpty) ? message : null;
    return SsCarte(
      key: ObjectKey(b),
      child: Opacity(
        opacity: b.retenue ? 1 : 0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Checkbox(
                value: b.retenue,
                activeColor: SsColors.primaire,
                onChanged: (v) => setState(() => b.retenue = v ?? false),
              ),
              Expanded(
                  child: Text('Suggestion $numero', style: SsText.titreCarte)),
              Text('Durée estimée : ${b.dureeJours} j',
                  style: SsText.secondaire),
            ]),
            const SizedBox(height: 8),
            TextFormField(
              controller: b.titre,
              decoration: ssChamp('Titre', icone: Icons.title),
              validator: (v) => obligatoire(v, 'Le titre est obligatoire'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: b.description,
              minLines: 2,
              maxLines: 4,
              decoration: ssChamp('Description', icone: Icons.notes),
              validator: (v) =>
                  obligatoire(v, 'La description est obligatoire'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<UserRole>(
              initialValue: b.role,
              isExpanded: true,
              decoration: ssChamp('Rôle requis', icone: Icons.badge_outlined),
              items: [
                for (final r in UserRole.values)
                  DropdownMenuItem(value: r, child: Text(r.label)),
              ],
              onChanged: (r) {
                if (r != null) setState(() => b.role = r);
              },
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _champDate('Début', b.debutAffiche, null,
                    () => _choisirDate(b, true)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _champDate(
                  'Fin',
                  b.finAffiche,
                  (_) => b.retenue && b.fin.compareTo(b.debut) < 0
                      ? 'Fin avant le début'
                      : null,
                  () => _choisirDate(b, false),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _erreur(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EtatVide(icone: Icons.cloud_off_outlined, message: message),
          TextButton.icon(
            onPressed: _reessayer,
            icon: const Icon(Icons.refresh, color: SsColors.primaire),
            label: const Text('Réessayer',
                style: TextStyle(color: SsColors.primaire)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SsColors.fond,
      appBar: projetAppBar('Suggestions IA'),
      body: FutureBuilder<List<_Brouillon>>(
        future: _brouillons,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Gemini prépare des suggestions…',
                      style: SsText.secondaire),
                ],
              ),
            );
          }
          if (snap.hasError) {
            final e = snap.error;
            return _erreur(e is SuggestionException ? e.message : 'Erreur : $e');
          }
          final brouillons = snap.data!;
          if (brouillons.isEmpty) {
            return _erreur('L\'IA n\'a proposé aucune tâche exploitable.');
          }
          final nb = brouillons.where((b) => b.retenue).length;
          return Form(
            key: _formKey,
            child: Column(children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: brouillons.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Relisez les suggestions : rien n\'est créé tant que '
                          'vous n\'avez pas cliqué sur « Créer ».',
                          style: SsText.secondaire,
                        ),
                      );
                    }
                    return _carte(brouillons[i - 1], i);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SsBoutonPrincipal(
                  label: _enCours ? 'Création…' : 'Créer $nb tâche(s)',
                  onPressed: _enCours || nb == 0
                      ? null
                      : () => _enregistrer(brouillons),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}
