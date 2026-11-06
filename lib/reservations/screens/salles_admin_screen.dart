import 'package:flutter/material.dart';

import '../models/reservation.dart';
import '../models/salle.dart';
import '../services/reservation_service.dart';
import '../ui/smartspace_style.dart';
import 'salle_form_screen.dart';

/// Liste des salles, avec ajout / modification / suppression (administrateur).
class SallesAdminScreen extends StatefulWidget {
  const SallesAdminScreen({super.key, required this.service});
  final ReservationService service;

  @override
  State<SallesAdminScreen> createState() => _SallesAdminScreenState();
}

class _SallesAdminScreenState extends State<SallesAdminScreen> {
  late Future<(List<Salle>, Map<int, List<Reservation>>)> _donnees;

  @override
  void initState() {
    super.initState();
    _donnees = _lire();
  }

  Future<(List<Salle>, Map<int, List<Reservation>>)> _lire() async {
    final salles = await widget.service.getSalles();
    final resas = await widget.service
        .getReservationsAVenirParSalle(formatDate(DateTime.now()));
    return (salles, resas);
  }

  void _charger() {
    setState(() {
      _donnees = _lire();
    });
  }

  Future<void> _ouvrirFormulaire([Salle? salle]) async {
    final modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => SalleFormScreen(service: widget.service, salle: salle)),
    );
    if (modifie == true) _charger();
  }

  Future<void> _supprimer(Salle salle) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la salle ?'),
        content: Text(
            'La salle n°${salle.numero} et toutes ses réservations seront supprimées.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: SsColors.alerte)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.service.supprimerSalle(salle.id!);
    if (!mounted) return;
    ssMessage(context, 'Salle supprimée');
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SsColors.fond,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SsColors.primaire,
        foregroundColor: Colors.white,
        onPressed: () => _ouvrirFormulaire(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter une salle'),
      ),
      body: FutureBuilder<(List<Salle>, Map<int, List<Reservation>>)>(
        future: _donnees,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erreur : ${snap.error}'));
          }
          final (salles, resasParSalle) = snap.data!;
          if (salles.isEmpty) {
            return const Center(
              child: Text('Aucune salle référencée.\nAjoutez la première salle.',
                  textAlign: TextAlign.center, style: SsText.secondaire),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: salles.length,
            itemBuilder: (context, i) {
              final s = salles[i];
              final resas = resasParSalle[s.id] ?? const <Reservation>[];
              final reservee = resas.isNotEmpty;
              return SsCarte(
                onTap: () => _ouvrirFormulaire(s),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.meeting_room_outlined,
                        color: reservee ? SsColors.alerte : SsColors.primaire),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('Salle ${s.numero}', style: SsText.titreCarte),
                              SsBadge(
                                label: reservee
                                    ? 'Réservée (${resas.length})'
                                    : 'Libre',
                                couleur: reservee ? SsColors.alerte : SsColors.succes,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(s.emplacement, style: SsText.secondaire),
                          // Réservations à venir de cette salle.
                          for (final r in resas)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(children: [
                                const Icon(Icons.event, size: 14, color: SsColors.alerte),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${afficherDate(r.date)} · ${r.heureDebut}–${r.heureFin} · '
                                    '${r.objet} (${r.nbPersonnes} pers.)',
                                    style: SsText.secondaire,
                                  ),
                                ),
                              ]),
                            ),
                        ],
                      ),
                    ),
                    SsBadge(label: '${s.capacite} pers.', couleur: SsColors.secondaire),
                    IconButton(
                      tooltip: 'Supprimer',
                      icon: const Icon(Icons.delete_outline, color: SsColors.alerte),
                      onPressed: () => _supprimer(s),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
