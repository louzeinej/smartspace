import 'package:flutter/material.dart';

import '../../reservations/ui/smartspace_style.dart';
import '../models/statut_tache.dart';
import '../models/tache.dart';
import '../services/projet_service.dart';
import '../ui/projet_widgets.dart';

/// Tâches affectées à l'utilisateur connecté, avec mise à jour du statut.
class MesTachesScreen extends StatefulWidget {
  const MesTachesScreen({super.key, required this.service});
  final ProjetService service;

  @override
  State<MesTachesScreen> createState() => _MesTachesScreenState();
}

class _MesTachesScreenState extends State<MesTachesScreen> {
  late Future<List<Tache>> _taches;

  @override
  void initState() {
    super.initState();
    _taches = _lire();
    widget.service.changements.addListener(_charger);
  }

  @override
  void dispose() {
    widget.service.changements.removeListener(_charger);
    super.dispose();
  }

  Future<List<Tache>> _lire() =>
      widget.service.getTachesUtilisateur(widget.service.acteur.utilisateurId);

  void _charger() {
    setState(() {
      _taches = _lire();
    });
  }

  Future<void> _changerStatut(Tache tache, StatutTache statut,
      {bool retirerAffectation = false}) async {
    if (statut == tache.statut) return;
    try {
      await widget.service.changerStatut(tache.id!, statut,
          retirerAffectation: retirerAffectation);
      if (mounted) ssMessage(context, 'Statut mis à jour');
    } on ConflitAffectationException catch (e) {
      if (!mounted) return;
      final retirer = await proposerRetraitAffectation(context, e);
      if (retirer && mounted) {
        await _changerStatut(tache, statut, retirerAffectation: true);
      }
    } on ProjetException catch (e) {
      if (mounted) ssMessage(context, e.message, erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SsColors.fond,
      child: FutureBuilder<List<Tache>>(
        future: _taches,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erreur : ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final taches = snap.data!;
          if (taches.isEmpty) {
            return const Center(
              child: EtatVide(
                icone: Icons.task_alt,
                message: 'Aucune tâche ne vous est affectée.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _charger(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: taches.length,
              itemBuilder: (context, i) {
                final t = taches[i];
                return SsCarte(
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.titre, style: SsText.titreCarte),
                          const SizedBox(height: 2),
                          Text('Projet : ${t.projetTitre}',
                              style: SsText.secondaire),
                          Text(afficherPeriode(t.dateDebut, t.dateFin),
                              style: SsText.secondaire),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      // Affiche toujours la valeur en base : un changement
                      // refusé revient donc tout seul au statut réel.
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<StatutTache>(
                          value: t.statut,
                          style: SsText.courant
                              .copyWith(color: SsColors.secondaire),
                          items: [
                            for (final s in StatutTache.values)
                              DropdownMenuItem(value: s, child: Text(s.label)),
                          ],
                          onChanged: (s) {
                            if (s != null) _changerStatut(t, s);
                          },
                        ),
                      ),
                    ),
                  ]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
