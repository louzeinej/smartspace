import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../entities/evenement.dart';
import '../entities/utilisateur_courant.dart';
import '../services/donnees_demo_service.dart';
import '../services/evenement_service.dart';
import 'evenement_detail_screen.dart';
import 'evenement_form_screen.dart';
import 'image_evenement.dart';
import 'mes_inscriptions_screen.dart';
import 'statistiques_screen.dart';

class EvenementListScreen extends StatefulWidget {
  const EvenementListScreen({super.key});

  @override
  State<EvenementListScreen> createState() => _EvenementListScreenState();
}

class _EvenementListScreenState extends State<EvenementListScreen> {
  final EvenementService _evenementService = EvenementService();
  List<Evenement> _evenements = [];
  // Controller du défilement (partagé par la Scrollbar et la liste)
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _demarrer();
  }

  // Premier chargement de l'écran
  Future<void> _demarrer() async {
    // À SUPPRIMER avant l'intégration : crée des données de test en mode debug
    if (kDebugMode && kCreerDonneesDemo) {
      try {
        await DonneesDemoService().creerJeuDeTest();
      } catch (e) {
        // On ignore l'erreur : l'écran doit s'afficher quand même
      }
    }
    await chargerEvenements();
  }

  // Libère le controller quand l'écran est fermé
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Remonte doucement tout en haut de la liste
  void _allerEnHaut() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  // Descend doucement tout en bas de la liste
  void _allerEnBas() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  // Lit les événements dans la base puis met à jour l'écran
  Future<void> chargerEvenements() async {
    final liste = await _evenementService.lireTous();
    if (!mounted) return;
    setState(() {
      _evenements = liste;
    });
  }

  // Demande confirmation, puis supprime l'événement et recharge la liste
  Future<void> supprimerEvenement(Evenement evenement) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer l'événement ?"),
        content: Text(
          '« ${evenement.titre} » sera supprimé avec toutes ses activités '
          'et toutes les inscriptions. Cette action est définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    await _evenementService.supprimer(evenement.id!);
    await chargerEvenements();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Événement supprimé')),
    );
  }

  // Ouvre le formulaire (création si evenement est null) puis recharge
  Future<void> ouvrirFormulaire([Evenement? evenement]) async {
    final resultat = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EvenementFormScreen(evenement: evenement),
      ),
    );
    if (resultat == true) {
      chargerEvenements();
    }
  }

  // Ajoute des activités de démo, prévient l'utilisateur, puis recharge
  Future<void> ajouterDonneesDemo() async {
    final nombre = await DonneesDemoService().insererDonneesDemo();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2ECC71),
        content: Text(
          nombre == 0
              ? 'Aucune activité à ajouter : tous les événements en ont déjà'
              : '$nombre activité(s) ajoutée(s)',
        ),
      ),
    );
    await chargerEvenements();
  }

  // Inscrit l'employé courant à plusieurs activités (démo) et prévient
  Future<void> inscrireEmployeCourant() async {
    final nombre = await DonneesDemoService()
        .inscrireUtilisateurAuxActivites(UtilisateurCourant.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2ECC71),
        content: Text(
          nombre == 0
              ? 'Aucune activité disponible : lance d\'abord l\'outil de données de démo'
              : '${UtilisateurCourant.nom()} inscrit à $nombre activité(s)',
        ),
      ),
    );
  }

  // Ouvre le dialogue de simulation, puis change l'employé connecté
  Future<void> simulerConnexion() async {
    final numero = await showDialog<int>(
      context: context,
      builder: (context) => const _DialogueSimulerConnexion(),
    );
    // Dialogue annulé : on ne fait rien
    if (numero == null) return;

    await UtilisateurCourant.changer(numero);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2ECC71),
        content: Text('Connecté en tant que ${UtilisateurCourant.nom()}'),
      ),
    );
  }

  // Ouvre l'écran de détail d'un événement
  void ouvrirDetail(Evenement evenement) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EvenementDetailScreen(evenement: evenement),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Événements'),
        actions: [
          // Mes inscriptions (visible pour tous)
          IconButton(
            icon: const Icon(Icons.event_available, color: Colors.white),
            tooltip: 'Mes inscriptions',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MesInscriptionsScreen(),
                ),
              );
            },
          ),
          // Statistiques de participation (visible pour tous)
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.white),
            tooltip: 'Statistiques',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StatistiquesScreen(),
                ),
              );
            },
          ),
          // Outils de développement : visibles seulement en mode debug
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.dataset, color: Colors.white),
              tooltip: 'Ajouter des données de démo',
              onPressed: ajouterDonneesDemo,
            ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.playlist_add_check, color: Colors.white),
              tooltip: 'Inscrire l\'employé courant à des activités (démo)',
              onPressed: inscrireEmployeCourant,
            ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.account_circle, color: Colors.white),
              tooltip: 'Simuler une connexion',
              onPressed: simulerConnexion,
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Deux flèches toujours visibles : haut et bas de la liste
          FloatingActionButton.small(
            heroTag: 'liste_fleche_haut',
            tooltip: 'Haut de la liste',
            backgroundColor: const Color(0xFF7F5AF0),
            foregroundColor: Colors.white,
            onPressed: _allerEnHaut,
            child: const Icon(Icons.keyboard_arrow_up),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'liste_fleche_bas',
            tooltip: 'Bas de la liste',
            backgroundColor: const Color(0xFF7F5AF0),
            foregroundColor: Colors.white,
            onPressed: _allerEnBas,
            child: const Icon(Icons.keyboard_arrow_down),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'ajouter_evenement',
            backgroundColor: const Color(0xFF7F5AF0),
            foregroundColor: Colors.white,
            onPressed: () => ouvrirFormulaire(),
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: _evenements.isEmpty
          ? const Center(child: Text('Aucun événement'))
          // Barre de défilement toujours visible, liée au même controller
          : Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _scrollController,
                // Toujours défilable, même avec peu d'éléments
                physics: const AlwaysScrollableScrollPhysics(),
                // Grande marge en bas : les 3 boutons ne cachent pas la
                // corbeille de la dernière carte
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 160),
                itemCount: _evenements.length,
                itemBuilder: (context, index) {
                  final evenement = _evenements[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Photo de l'événement (exemple, importée ou vide)
                        ImageEvenement(image: evenement.image),
                        ListTile(
                          // Toucher la carte ouvre le détail de l'événement
                          onTap: () => ouvrirDetail(evenement),
                          title: Text(evenement.titre),
                          subtitle:
                              Text('${evenement.date} • ${evenement.lieu}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Crayon : ouvre le formulaire de modification
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => ouvrirFormulaire(evenement),
                              ),
                              // Corbeille : supprime l'événement
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => supprimerEvenement(evenement),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

// Dialogue "Simuler une connexion" : on tape l'ID de l'employé.
// Il renvoie l'ID valide, ou null si on annule.
class _DialogueSimulerConnexion extends StatefulWidget {
  const _DialogueSimulerConnexion();

  @override
  State<_DialogueSimulerConnexion> createState() =>
      _DialogueSimulerConnexionState();
}

class _DialogueSimulerConnexionState extends State<_DialogueSimulerConnexion> {
  late final TextEditingController _controller;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    // Valeur de départ = l'employé actuel
    _controller = TextEditingController(text: '${UtilisateurCourant.id}');
  }

  // Libère le controller quand le dialogue est fermé
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Vérifie l'ID : entier supérieur à 0, sinon on affiche l'erreur
  void _valider() {
    final numero = int.tryParse(_controller.text.trim());
    if (numero == null || numero <= 0) {
      setState(() => _erreur = 'Entrez un ID valide (entier supérieur à 0)');
      return;
    }
    Navigator.pop(context, numero);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Simuler une connexion'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        // Accepte seulement les chiffres (pas de virgule, de point ni de signe)
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'ID de l\'employé',
          helperText: 'Identifiant de l\'employé connecté, par exemple 205',
          errorText: _erreur,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _valider,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7F5AF0),
            foregroundColor: Colors.white,
          ),
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
