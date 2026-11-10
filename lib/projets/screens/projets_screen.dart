import 'package:flutter/material.dart';

import '../../reservations/ui/smartspace_style.dart';
import '../models/projet.dart';
import '../services/projet_service.dart';
import '../ui/projet_widgets.dart';
import 'projet_detail_screen.dart';
import 'projet_form_screen.dart';

/// Liste des projets. La création dépend du rôle de l'utilisateur.
class ProjetsScreen extends StatefulWidget {
  const ProjetsScreen({super.key, required this.service});
  final ProjetService service;

  @override
  State<ProjetsScreen> createState() => _ProjetsScreenState();
}

class _ProjetsScreenState extends State<ProjetsScreen> {
  late Future<List<Projet>> _projets;

  @override
  void initState() {
    super.initState();
    _projets = widget.service.getProjets();
    widget.service.changements.addListener(_charger);
  }

  @override
  void dispose() {
    widget.service.changements.removeListener(_charger);
    super.dispose();
  }

  void _charger() {
    setState(() {
      _projets = widget.service.getProjets();
    });
  }

  void _ouvrirFormulaire() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ProjetFormScreen(service: widget.service)),
    );
  }

  void _ouvrirDetail(Projet projet) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              ProjetDetailScreen(service: widget.service, projet: projet)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SsColors.fond,
      floatingActionButton: widget.service.peutCreerProjet
          ? FloatingActionButton.extended(
              // Tag unique : les 5 modules restent montés dans un IndexedStack.
              heroTag: 'projets_nouveau_projet',
              backgroundColor: SsColors.primaire,
              foregroundColor: Colors.white,
              onPressed: _ouvrirFormulaire,
              icon: const Icon(Icons.add),
              label: const Text('Nouveau projet'),
            )
          : null,
      body: FutureBuilder<List<Projet>>(
        future: _projets,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erreur : ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final projets = snap.data!;
          if (projets.isEmpty) {
            return const Center(
              child: EtatVide(
                icone: Icons.folder_open,
                message: 'Aucun projet pour le moment.',
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: projets.length,
            itemBuilder: (context, i) {
              final p = projets[i];
              return SsCarte(
                onTap: () => _ouvrirDetail(p),
                child: Row(children: [
                  const Icon(Icons.folder_outlined, color: SsColors.primaire),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.titre, style: SsText.titreCarte),
                        const SizedBox(height: 2),
                        Text(p.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: SsText.courant),
                        const SizedBox(height: 2),
                        Text('Créé le ${afficherDate(p.dateCreation)}',
                            style: SsText.secondaire),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: SsColors.secondaire),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
