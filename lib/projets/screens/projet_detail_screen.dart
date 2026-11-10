import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../reservations/ui/smartspace_style.dart';
import '../../widgets/role_badge.dart';
import '../models/projet.dart';
import '../models/tache.dart';
import '../services/projet_service.dart';
import '../ui/projet_widgets.dart';
import 'affectation_screen.dart';
import 'projet_form_screen.dart';
import 'tache_form_screen.dart';

/// Détail d'un projet et de ses tâches.
class ProjetDetailScreen extends StatefulWidget {
  const ProjetDetailScreen(
      {super.key, required this.service, required this.projet});
  final ProjetService service;
  final Projet projet;

  @override
  State<ProjetDetailScreen> createState() => _ProjetDetailScreenState();
}

class _ProjetDetailScreenState extends State<ProjetDetailScreen> {
  late Future<(Projet?, List<Tache>, Map<int, User>)> _donnees;

  @override
  void initState() {
    super.initState();
    _donnees = _lire();
    widget.service.changements.addListener(_charger);
  }

  @override
  void dispose() {
    widget.service.changements.removeListener(_charger);
    super.dispose();
  }

  Future<(Projet?, List<Tache>, Map<int, User>)> _lire() async {
    final id = widget.projet.id!;
    final projet = await widget.service.getProjet(id);
    final taches = await widget.service.getTachesProjet(id);
    final utilisateurs = await widget.service.getUtilisateursParId();
    return (projet, taches, utilisateurs);
  }

  void _charger() {
    setState(() {
      _donnees = _lire();
    });
  }

  void _ouvrir(Widget ecran) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ecran));
  }

  Future<void> _supprimerProjet(Projet projet) async {
    final ok = await confirmerSuppression(
      context,
      titre: 'Supprimer le projet ?',
      message: '« ${projet.titre} » et toutes ses tâches seront supprimés.',
    );
    if (!ok) return;
    try {
      await widget.service.supprimerProjet(projet.id!);
      if (!mounted) return;
      ssMessage(context, 'Projet supprimé');
      Navigator.pop(context);
    } on ProjetException catch (e) {
      if (mounted) ssMessage(context, e.message, erreur: true);
    }
  }

  Future<void> _supprimerTache(Tache tache) async {
    final ok = await confirmerSuppression(
      context,
      titre: 'Supprimer la tâche ?',
      message: '« ${tache.titre} » sera supprimée.',
    );
    if (!ok) return;
    try {
      await widget.service.supprimerTache(tache.id!);
      if (mounted) ssMessage(context, 'Tâche supprimée');
    } on ProjetException catch (e) {
      if (mounted) ssMessage(context, e.message, erreur: true);
    }
  }

  Widget _carteProjet(Projet projet) {
    return SsCarte(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(projet.description, style: SsText.courant),
            const SizedBox(height: 6),
            Text('Créé le ${afficherDate(projet.dateCreation)}',
                style: SsText.secondaire),
          ],
        ),
      ),
    );
  }

  Widget _carteTache(Tache t, Projet projet, Map<int, User> utilisateurs,
      {required bool peutGerer}) {
    final affectee = utilisateurs[t.utilisateurId];
    return SsCarte(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(t.titre, style: SsText.titreCarte)),
            const SizedBox(width: 8),
            StatutBadge(statut: t.statut),
          ]),
          const SizedBox(height: 4),
          Text(t.description, style: SsText.courant),
          const SizedBox(height: 4),
          Text(afficherPeriode(t.dateDebut, t.dateFin),
              style: SsText.secondaire),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              RoleBadge(role: t.roleRequis, small: true),
              Text(
                affectee == null
                    ? 'Non affectée'
                    : 'Affectée à ${affectee.fullName}',
                style: SsText.secondaire,
              ),
            ],
          ),
          if (peutGerer)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!t.statut.estTerminee)
                  TextButton(
                    onPressed: () => _ouvrir(AffectationScreen(
                        service: widget.service, tache: t)),
                    child: Text(affectee == null ? 'Affecter' : 'Réaffecter',
                        style: const TextStyle(color: SsColors.primaire)),
                  ),
                IconButton(
                  tooltip: 'Modifier la tâche',
                  icon: const Icon(Icons.edit_outlined,
                      color: SsColors.secondaire),
                  onPressed: () => _ouvrir(TacheFormScreen(
                      service: widget.service,
                      projetId: projet.id!,
                      tache: t)),
                ),
                IconButton(
                  tooltip: 'Supprimer la tâche',
                  icon: const Icon(Icons.delete_outline,
                      color: SsColors.alerte),
                  onPressed: () => _supprimerTache(t),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Projet?, List<Tache>, Map<int, User>)>(
      future: _donnees,
      builder: (context, snap) {
        final chargement = !snap.hasData && !snap.hasError;
        final existe = snap.hasData && snap.data!.$1 != null;
        final projet = snap.data?.$1 ?? widget.projet;
        final peutGerer = existe && widget.service.peutGererProjet(projet);
        return Scaffold(
          backgroundColor: SsColors.fond,
          appBar: projetAppBar(
            projet.titre,
            actions: [
              if (peutGerer) ...[
                IconButton(
                  tooltip: 'Modifier le projet',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _ouvrir(ProjetFormScreen(
                      service: widget.service, projet: projet)),
                ),
                IconButton(
                  tooltip: 'Supprimer le projet',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _supprimerProjet(projet),
                ),
              ],
            ],
          ),
          floatingActionButton: peutGerer
              ? FloatingActionButton.extended(
                  heroTag: 'projets_nouvelle_tache',
                  backgroundColor: SsColors.primaire,
                  foregroundColor: Colors.white,
                  onPressed: () => _ouvrir(TacheFormScreen(
                      service: widget.service, projetId: projet.id!)),
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvelle tâche'),
                )
              : null,
          body: () {
            if (snap.hasError) {
              return Center(child: Text('Erreur : ${snap.error}'));
            }
            if (chargement) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!existe) {
              return const Center(
                child: EtatVide(
                  icone: Icons.folder_off_outlined,
                  message: 'Ce projet n\'existe plus.',
                ),
              );
            }
            final (_, taches, utilisateurs) = snap.data!;
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: 1 + (taches.isEmpty ? 1 : taches.length),
              itemBuilder: (context, i) {
                if (i == 0) return _carteProjet(projet);
                if (taches.isEmpty) {
                  return const EtatVide(
                    icone: Icons.checklist,
                    message: 'Aucune tâche dans ce projet.',
                  );
                }
                return _carteTache(taches[i - 1], projet, utilisateurs,
                    peutGerer: peutGerer);
              },
            );
          }(),
        );
      },
    );
  }
}
