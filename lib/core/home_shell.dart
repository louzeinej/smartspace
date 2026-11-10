import 'package:flutter/material.dart';

import '../modules/evenements/screens/evenement_list_screen.dart';
import '../networking/networking_module.dart';
import '../projets/projets_module.dart';
import '../reservations/reservations_module.dart';
import '../screens/users_screen.dart';
import '../reservations/ui/smartspace_style.dart';
import 'session.dart';

/// Écran principal : barre de navigation basse à 5 icônes, une par module
/// (section 8.3 du cahier des charges). Icône active en violet primaire.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0; // ouvre sur l'annuaire Utilisateurs

  @override
  Widget build(BuildContext context) {
    final modules = <Widget>[
      const UsersScreen(), // Module Utilisateurs (Youssef Messoudi)
      const ProjetsModule(), // Module Projets et Tâches (Youssef Sghaier)
      ReservationsModule(
        utilisateurId: Session.utilisateurId,
        estAdmin: Session.estAdmin,
      ),
      NetworkingModule(
        utilisateurId: Session.utilisateurId,
        estAdmin: Session.estAdmin,
      ), // Module Networking (Manar Kalai)
      const EvenementListScreen(), // Module Événements et Club (Louzeine Aloui)
    ];

    return Scaffold(
      // IndexedStack garde l'état de chaque module quand on change d'onglet.
      body: IndexedStack(index: _index, children: modules),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: SsColors.primaire,
        unselectedItemColor: const Color(0x802D2A4A),
        backgroundColor: Colors.white,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Utilisateurs'),
          BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: 'Projets'),
          BottomNavigationBarItem(icon: Icon(Icons.meeting_room_outlined), label: 'Salles'),
          BottomNavigationBarItem(icon: Icon(Icons.forum_outlined), label: 'Réseau'),
          BottomNavigationBarItem(icon: Icon(Icons.celebration_outlined), label: 'Événements'),
        ],
      ),
    );
  }
}

/// Emplacement réservé au module d'un autre membre de l'équipe.
class _ModuleAVenir extends StatelessWidget {
  const _ModuleAVenir({required this.nom, required this.responsable});
  final String nom;
  final String responsable;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SsColors.fond,
      appBar: AppBar(
        backgroundColor: SsColors.primaire,
        foregroundColor: Colors.white,
        title: Text(nom),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Module en cours de développement\npar $responsable',
              textAlign: TextAlign.center, style: SsText.secondaire),
        ),
      ),
    );
  }
}
