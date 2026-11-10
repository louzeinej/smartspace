import 'package:flutter/material.dart';

import '../models/reservation.dart';
import '../services/reservation_service.dart';
import '../ui/smartspace_style.dart';
import 'modifier_reservation_screen.dart';

/// Réservations de l'utilisateur connecté, avec modification et annulation.
class MesReservationsScreen extends StatefulWidget {
  const MesReservationsScreen(
      {super.key, required this.service, required this.utilisateurId});
  final ReservationService service;
  final int utilisateurId;

  @override
  State<MesReservationsScreen> createState() => MesReservationsScreenState();
}

class MesReservationsScreenState extends State<MesReservationsScreen> {
  late Future<List<Reservation>> _reservations;

  @override
  void initState() {
    super.initState();
    _reservations = widget.service.getReservationsUtilisateur(widget.utilisateurId);
  }

  void recharger() {
    setState(() {
      _reservations = widget.service.getReservationsUtilisateur(widget.utilisateurId);
    });
  }

  bool _estPassee(Reservation r) {
    final maintenant = DateTime.now();
    final aujourdhui = formatDate(maintenant);
    final heure = formatHeure(TimeOfDay.fromDateTime(maintenant));
    return r.date.compareTo(aujourdhui) < 0 ||
        (r.date == aujourdhui && r.heureFin.compareTo(heure) <= 0);
  }

  Future<void> _modifier(Reservation r) async {
    final modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              ModifierReservationScreen(service: widget.service, reservation: r)),
    );
    if (modifie == true) recharger();
  }

  Future<void> _annuler(Reservation r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la réservation ?'),
        content: Text('Salle ${r.salleNumero} — ${afficherDate(r.date)} '
            'de ${r.heureDebut} à ${r.heureFin}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui, annuler', style: TextStyle(color: SsColors.alerte)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.service.annulerReservation(r.id!);
    if (!mounted) return;
    ssMessage(context, 'Réservation annulée');
    recharger();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SsColors.fond,
      child: FutureBuilder<List<Reservation>>(
        future: _reservations,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Erreur : ${snap.error}'));
          final liste = snap.data!;
          if (liste.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_available, size: 48, color: SsColors.primaire),
                    const SizedBox(height: 12),
                    const Text('Vous n\'avez aucune réservation.', style: SsText.courant),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 280,
                      child: SsBoutonPrincipal(
                        label: 'Réserver une salle',
                        // Bascule sur l'onglet « Réserver » (index 0).
                        onPressed: () => DefaultTabController.of(context).animateTo(0),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => recharger(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: liste.length,
              itemBuilder: (context, i) {
                final r = liste[i];
                final passee = _estPassee(r);
                return SsCarte(
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.objet, style: SsText.titreCarte),
                          const SizedBox(height: 4),
                          Text('Salle ${r.salleNumero} · ${r.salleEmplacement}',
                              style: SsText.secondaire),
                          Text(
                              '${afficherDate(r.date)} · ${r.heureDebut}–${r.heureFin} · '
                              '${r.nbPersonnes} pers.',
                              style: SsText.secondaire),
                          const SizedBox(height: 6),
                          SsBadge(
                            label: passee ? 'Terminée' : 'À venir',
                            couleur: passee ? SsColors.secondaire : SsColors.succes,
                          ),
                        ],
                      ),
                    ),
                    if (!passee)
                      IconButton(
                        tooltip: 'Modifier',
                        icon: const Icon(Icons.edit_outlined, color: SsColors.primaire),
                        onPressed: () => _modifier(r),
                      ),
                    if (!passee)
                      IconButton(
                        tooltip: 'Annuler',
                        icon: const Icon(Icons.cancel_outlined, color: SsColors.alerte),
                        onPressed: () => _annuler(r),
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
