import 'package:flutter/material.dart';

import '../reservations/ui/smartspace_style.dart';
import 'screens/mes_taches_screen.dart';
import 'screens/projets_screen.dart';
import 'services/projet_service.dart';
import 'ui/projet_widgets.dart';

/// Point d'entrée du module « Gestion de Projets et des Tâches ».
///
/// Les deux onglets partagent le même service : une écriture dans l'un
/// recharge l'autre. L'utilisateur connecté est lu dans `Session`.
class ProjetsModule extends StatefulWidget {
  const ProjetsModule({super.key, this.service});

  final ProjetService? service;

  @override
  State<ProjetsModule> createState() => _ProjetsModuleState();
}

class _ProjetsModuleState extends State<ProjetsModule> {
  late final ProjetService _service = widget.service ?? ProjetService();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: SsColors.fond,
        appBar: projetAppBar(
          'Projets et tâches',
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.folder_outlined), text: 'Projets'),
              Tab(icon: Icon(Icons.task_alt), text: 'Mes tâches'),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: TabBarView(children: [
          ProjetsScreen(service: _service),
          MesTachesScreen(service: _service),
        ]),
      ),
    );
  }
}
