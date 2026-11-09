import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../reservations/ui/smartspace_style.dart';
import '../../widgets/role_badge.dart';
import '../models/tache.dart';
import '../services/projet_service.dart';
import '../ui/projet_widgets.dart';

/// Choix de la personne à qui affecter une tâche : uniquement les
/// utilisateurs ayant le rôle requis, avec leur disponibilité sur la période.
class AffectationScreen extends StatefulWidget {
  const AffectationScreen(
      {super.key, required this.service, required this.tache});
  final ProjetService service;
  final Tache tache;

  @override
  State<AffectationScreen> createState() => _AffectationScreenState();
}

class _AffectationScreenState extends State<AffectationScreen> {
  late Future<List<Candidat>> _candidats;

  @override
  void initState() {
    super.initState();
    _candidats = widget.service.evaluerCandidats(widget.tache);
  }

  void _charger() {
    setState(() {
      _candidats = widget.service.evaluerCandidats(widget.tache);
    });
  }

  Future<void> _affecter(User utilisateur) async {
    try {
      await widget.service.affecterA(widget.tache, utilisateur);
      if (!mounted) return;
      ssMessage(context, 'Tâche affectée à ${utilisateur.fullName}');
      Navigator.pop(context);
    } on ProjetException catch (e) {
      if (!mounted) return;
      ssMessage(context, e.message, erreur: true);
      _charger();
    }
  }

  Widget _carteCandidat(Candidat c) {
    final u = c.utilisateur;
    final dispo = c.disponibilite;
    final conflit = dispo.conflit;
    final dejaAffectee = widget.tache.utilisateurId == u.id;
    return SsCarte(
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(u.fullName, style: SsText.titreCarte),
                  SsBadge(
                    label: dispo.estDisponible ? 'Disponible' : 'Occupé',
                    couleur:
                        dispo.estDisponible ? SsColors.succes : SsColors.alerte,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(u.email, style: SsText.secondaire),
              if (conflit != null)
                Text(
                  'Sur « ${conflit.titre} » (${conflit.projetTitre}) · '
                  '${afficherPeriode(conflit.dateDebut, conflit.dateFin)}',
                  style: SsText.secondaire.copyWith(color: SsColors.alerte),
                )
              else if (!dispo.personneDisponible)
                Text('Déclaré indisponible',
                    style: SsText.secondaire.copyWith(color: SsColors.alerte)),
            ],
          ),
        ),
        if (dejaAffectee)
          const Text('Affectée', style: SsText.secondaire)
        else if (dispo.estDisponible)
          TextButton(
            onPressed: () => _affecter(u),
            child: const Text('Affecter',
                style: TextStyle(color: SsColors.primaire)),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tache;
    return Scaffold(
      backgroundColor: SsColors.fond,
      appBar: projetAppBar('Affecter la tâche'),
      body: FutureBuilder<List<Candidat>>(
        future: _candidats,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erreur : ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final candidats = snap.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 1 + (candidats.isEmpty ? 1 : candidats.length),
            itemBuilder: (context, i) {
              if (i == 0) {
                return SsCarte(
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.titre, style: SsText.titreCarte),
                          const SizedBox(height: 2),
                          Text(afficherPeriode(t.dateDebut, t.dateFin),
                              style: SsText.secondaire),
                        ],
                      ),
                    ),
                    RoleBadge(role: t.roleRequis, small: true),
                  ]),
                );
              }
              if (candidats.isEmpty) {
                return EtatVide(
                  icone: Icons.person_off_outlined,
                  message: 'Aucun utilisateur n\'a le rôle '
                      '${t.roleRequis.label}.',
                );
              }
              return _carteCandidat(candidats[i - 1]);
            },
          );
        },
      ),
    );
  }
}
