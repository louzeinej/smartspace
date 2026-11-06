import 'package:flutter/material.dart';

import 'screens/mes_reservations_screen.dart';
import 'screens/recherche_salle_screen.dart';
import 'screens/salles_admin_screen.dart';
import 'services/reservation_service.dart';
import 'ui/smartspace_style.dart';

/// Point d'entrée du module « Gestion des Réservations de Salles ».
///
/// À brancher sur l'icône du module dans la barre de navigation basse.
/// [utilisateurId] et [estAdmin] viennent du module Utilisateurs
/// (utilisateur connecté et son rôle).
class ReservationsModule extends StatefulWidget {
  const ReservationsModule({
    super.key,
    required this.utilisateurId,
    required this.estAdmin,
    this.service,
  });

  final int utilisateurId;
  final bool estAdmin;
  final ReservationService? service;

  @override
  State<ReservationsModule> createState() => _ReservationsModuleState();
}

class _ReservationsModuleState extends State<ReservationsModule> {
  late final ReservationService _service = widget.service ?? ReservationService();
  final _mesResaKey = GlobalKey<MesReservationsScreenState>();

  @override
  Widget build(BuildContext context) {
    final onglets = <Tab>[
      const Tab(icon: Icon(Icons.search), text: 'Réserver'),
      const Tab(icon: Icon(Icons.event_note), text: 'Mes réservations'),
      if (widget.estAdmin) const Tab(icon: Icon(Icons.meeting_room), text: 'Salles'),
    ];
    return DefaultTabController(
      length: onglets.length,
      child: Scaffold(
        backgroundColor: SsColors.fond,
        appBar: AppBar(
          backgroundColor: SsColors.primaire,
          foregroundColor: Colors.white,
          title: const Text('Réservations de salles'),
          bottom: TabBar(
            tabs: onglets,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: TabBarView(children: [
          RechercheSalleScreen(
            service: _service,
            utilisateurId: widget.utilisateurId,
            onReservee: () => _mesResaKey.currentState?.recharger(),
          ),
          MesReservationsScreen(
            key: _mesResaKey,
            service: _service,
            utilisateurId: widget.utilisateurId,
          ),
          if (widget.estAdmin) SallesAdminScreen(service: _service),
        ]),
      ),
    );
  }
}
