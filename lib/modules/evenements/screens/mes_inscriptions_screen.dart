import 'package:flutter/material.dart';
import '../entities/statut_activite.dart';
import '../entities/utilisateur_courant.dart';
import '../services/activite_service.dart';
import '../services/evenement_service.dart';
import '../services/participation_service.dart';
import 'evenement_detail_screen.dart';

// Une participation avec son statut calculé
class _Inscription {
  final Map<String, Object?> ligne;
  final StatutActivite statut;

  _Inscription(this.ligne, this.statut);
}

// Écran "Mes inscriptions" : activités où l'employé courant participe
class MesInscriptionsScreen extends StatefulWidget {
  const MesInscriptionsScreen({super.key});

  @override
  State<MesInscriptionsScreen> createState() => _MesInscriptionsScreenState();
}

class _MesInscriptionsScreenState extends State<MesInscriptionsScreen> {
  // Couleurs de la charte
  static const Color violet = Color(0xFF7F5AF0);
  static const Color fond = Color(0xFFF7F7FB);
  static const Color rouge = Color(0xFFFF6B6B);
  static const Color vert = Color(0xFF2ECC71);
  static const Color titreCouleur = Color(0xFF1F2033);
  static const Color secondaire = Color(0xFF8E8EA8);

  final ParticipationService _participationService = ParticipationService();
  final ActiviteService _activiteService = ActiviteService();
  final EvenementService _evenementService = EvenementService();

  List<_Inscription> _inscriptions = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    chargerInscriptions();
  }

  // Lit les participations de l'employé puis calcule le statut de chacune
  Future<void> chargerInscriptions() async {
    final lignes =
        await _participationService.lireParUtilisateur(UtilisateurCourant.id);
    final resultat = <_Inscription>[];
    for (final ligne in lignes) {
      final inscrits =
          await _activiteService.compterInscrits(ligne['activite_id'] as int);
      final statut = calculerStatut(
        dateEvenement: ligne['date_evenement'] as String,
        heureDebut: ligne['heure_debut'] as String,
        heureFin: ligne['heure_fin'] as String,
        capaciteMax: ligne['capacite_max'] as int,
        inscrits: inscrits,
        capaciteMin: (ligne['capacite_min'] as int?) ?? 0,
      );
      resultat.add(_Inscription(ligne, statut));
    }
    if (!mounted) return;
    setState(() {
      _inscriptions = resultat;
      _chargement = false;
    });
  }

  // Affiche un message en bas de l'écran
  void _afficherMessage(String texte, Color couleur) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: couleur, content: Text(texte)),
    );
  }

  // Ouvre le détail de l'événement, puis recharge la liste au retour
  Future<void> ouvrirEvenement(_Inscription inscription) async {
    final evenement = await _evenementService.lireParId(
      inscription.ligne['evenement_id'] as int,
    );
    if (evenement == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EvenementDetailScreen(evenement: evenement),
      ),
    );
    await chargerInscriptions();
  }

  // Demande confirmation puis annule la participation
  Future<void> annulerParticipation(_Inscription inscription) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler votre participation ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: rouge),
            child: const Text('Annuler ma participation'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    try {
      await _participationService.desinscrire(
        inscription.ligne['activite_id'] as int,
        UtilisateurCourant.id,
      );
      if (!mounted) return;
      _afficherMessage('Participation annulée', vert);
    } catch (e) {
      if (!mounted) return;
      _afficherMessage(e.toString().replaceFirst('Exception: ', ''), rouge);
    }
    await chargerInscriptions();
  }

  // Construit la carte d'une participation
  Widget _carte(_Inscription inscription, bool aVenir) {
    final ligne = inscription.ligne;
    final statut = inscription.statut;
    final personnes = ligne['nombre_personnes'] as int;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () => ouvrirEvenement(inscription),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre de l'activité + badge du statut
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      ligne['activite_titre'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: titreCouleur,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statut.couleur,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statut.libelle,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Événement : ${ligne['evenement_titre']}'),
              const SizedBox(height: 6),
              // Date et horaires
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: violet),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${ligne['date_evenement']} • '
                      '${ligne['heure_debut']} - ${ligne['heure_fin']}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Lieu
              Row(
                children: [
                  const Icon(Icons.place, size: 14, color: secondaire),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${ligne['lieu']}',
                      style: const TextStyle(fontSize: 12, color: secondaire),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Nombre de personnes inscrites par l'employé
              Row(
                children: [
                  const Icon(Icons.people, size: 14, color: violet),
                  const SizedBox(width: 6),
                  Text('$personnes personne(s)'),
                ],
              ),
              // Bouton d'annulation : seulement pour les activités à venir
              if (aVenir)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => annulerParticipation(inscription),
                    style: TextButton.styleFrom(foregroundColor: rouge),
                    child: const Text('Annuler ma participation'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Construit la liste d'un onglet (ou le message s'il est vide)
  Widget _liste(List<_Inscription> liste, bool aVenir, String messageVide) {
    if (liste.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            messageVide,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: liste.length,
      itemBuilder: (context, index) => _carte(liste[index], aVenir),
    );
  }

  @override
  Widget build(BuildContext context) {
    // À venir : ni terminée ni annulée ; Passées : terminée ou annulée
    bool passee(_Inscription i) =>
        i.statut == StatutActivite.terminee ||
        i.statut == StatutActivite.annulee;
    final aVenir = _inscriptions.where((i) => !passee(i)).toList();
    final passees = _inscriptions.where(passee).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: fond,
        appBar: AppBar(
          title: const Text('Mes inscriptions'),
          backgroundColor: violet,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'À venir'),
              Tab(text: 'Passées'),
            ],
          ),
        ),
        body: _chargement
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // En-tête : nombre de participations à venir
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${aVenir.length} participation(s) à venir',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: titreCouleur,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _liste(
                          aVenir,
                          true,
                          'Vous ne participez à aucune activité pour le moment',
                        ),
                        _liste(passees, false, 'Aucune participation passée'),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
