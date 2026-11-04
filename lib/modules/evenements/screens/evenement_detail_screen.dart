import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../entities/activite.dart';
import '../entities/evenement.dart';
import '../entities/utilisateur_courant.dart';
import '../services/activite_service.dart';
import '../services/participation_service.dart';
import 'activite_form_screen.dart';
import 'image_evenement.dart';

// Petite classe qui regroupe une activité, son nombre d'inscrits
// et l'info "est-ce que l'utilisateur courant participe ?"
class _ActiviteAvecInscrits {
  final Activite activite;
  final int inscrits;
  // Nombre de personnes inscrites par l'utilisateur courant (0 = pas inscrit)
  final int mesPersonnes;

  _ActiviteAvecInscrits(this.activite, this.inscrits, this.mesPersonnes);

  bool get participe => mesPersonnes > 0;
}

// Contenu du dialogue "Combien de personnes participent ?"
// C'est un StatefulWidget à part pour que le nombre se mette à jour à l'écran
class ChoixNombrePersonnes extends StatefulWidget {
  // Nombre maximum de personnes
  final int maximum;
  // Nombre affiché au départ
  final int initial;
  // Nombre minimum de personnes
  final int minimum;
  // Titre du dialogue
  final String titre;

  const ChoixNombrePersonnes({
    super.key,
    required this.maximum,
    this.initial = 1,
    this.minimum = 1,
    this.titre = 'Combien de personnes participent ?',
  });

  @override
  State<ChoixNombrePersonnes> createState() => _ChoixNombrePersonnesState();
}

class _ChoixNombrePersonnesState extends State<ChoixNombrePersonnes> {
  late int _nombre;

  @override
  void initState() {
    super.initState();
    _nombre = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titre),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // "−" désactivé quand on est au minimum
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: _nombre > widget.minimum
                ? () => setState(() => _nombre--)
                : null,
          ),
          Text(
            '$_nombre',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          // "+" désactivé quand on atteint le maximum
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _nombre < widget.maximum
                ? () => setState(() => _nombre++)
                : null,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _nombre),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7F5AF0),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Confirmer'),
        ),
      ],
    );
  }
}

// Écran de détail : infos de l'événement + liste de ses activités
class EvenementDetailScreen extends StatefulWidget {
  final Evenement evenement;

  const EvenementDetailScreen({super.key, required this.evenement});

  @override
  State<EvenementDetailScreen> createState() => _EvenementDetailScreenState();
}

class _EvenementDetailScreenState extends State<EvenementDetailScreen> {
  // Couleurs de la charte
  static const Color violet = Color(0xFF7F5AF0);
  static const Color fond = Color(0xFFF7F7FB);
  static const Color rouge = Color(0xFFFF6B6B);
  static const Color vert = Color(0xFF2ECC71);

  final ActiviteService _activiteService = ActiviteService();
  final ParticipationService _participationService = ParticipationService();
  List<_ActiviteAvecInscrits> _activites = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    chargerActivites();
  }

  // Lit les activités de l'événement, puis le nombre d'inscrits de chacune
  Future<void> chargerActivites() async {
    final id = widget.evenement.id;
    final resultat = <_ActiviteAvecInscrits>[];
    if (id != null) {
      final liste = await _activiteService.lireParEvenement(id);
      for (final activite in liste) {
        final inscrits = await _activiteService.compterInscrits(activite.id!);
        // Combien de personnes l'utilisateur courant a-t-il inscrites ?
        // (0 s'il ne participe pas)
        final mesPersonnes =
            await _participationService.nombrePersonnesInscrites(
          activite.id!,
          UtilisateurCourant.id,
        );
        resultat.add(_ActiviteAvecInscrits(activite, inscrits, mesPersonnes));
      }
    }
    if (!mounted) return;
    setState(() {
      _activites = resultat;
      _chargement = false;
    });
  }

  // Ouvre le formulaire (création si activite est null) puis recharge si besoin
  Future<void> ouvrirFormulaire([Activite? activite]) async {
    final id = widget.evenement.id;
    if (id == null) return;
    final resultat = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ActiviteFormScreen(evenementId: id, activite: activite),
      ),
    );
    if (resultat == true) {
      chargerActivites();
    }
  }

  // Demande confirmation, puis supprime l'activité et recharge la liste
  Future<void> supprimerActivite(Activite activite) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette activité ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    await _activiteService.supprimer(activite.id!);
    await chargerActivites();
  }

  // Affiche un message en bas de l'écran
  void _afficherMessage(String texte, Color couleur) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: couleur, content: Text(texte)),
    );
  }

  // Inscrit l'utilisateur courant à l'activité
  Future<void> participer(_ActiviteAvecInscrits element) async {
    final activite = element.activite;
    final restantes = activite.capaciteMax - element.inscrits;
    var nombre = 1;

    // S'il reste plus d'une place, on demande combien de personnes viennent
    if (restantes > 1) {
      final choix = await showDialog<int>(
        context: context,
        builder: (context) => ChoixNombrePersonnes(maximum: restantes),
      );
      // Dialogue annulé : on ne fait rien
      if (choix == null) return;
      nombre = choix;
    }

    try {
      await _participationService.inscrire(
        activite.id!,
        UtilisateurCourant.id,
        nombrePersonnes: nombre,
      );
      if (!mounted) return;
      _afficherMessage('Participation enregistrée ($nombre personne(s))', vert);
    } catch (e) {
      if (!mounted) return;
      // On enlève le préfixe "Exception: " du message
      _afficherMessage(e.toString().replaceFirst('Exception: ', ''), rouge);
    }
    await chargerActivites();
  }

  // Change le nombre de personnes de la participation de l'utilisateur
  Future<void> modifierParticipation(_ActiviteAvecInscrits element) async {
    final activite = element.activite;
    final restantes = activite.capaciteMax - element.inscrits;
    // Maximum = nombre actuel + places encore libres
    final maximum = element.mesPersonnes + restantes;

    final choix = await showDialog<int>(
      context: context,
      builder: (context) => ChoixNombrePersonnes(
        titre: 'Modifier le nombre de personnes',
        initial: element.mesPersonnes,
        maximum: maximum,
      ),
    );
    // Annulé ou nombre identique : on ne fait rien
    if (choix == null || choix == element.mesPersonnes) return;

    try {
      await _participationService.modifierNombrePersonnes(
        activite.id!,
        UtilisateurCourant.id,
        choix,
      );
      if (!mounted) return;
      _afficherMessage('Participation modifiée ($choix personne(s))', vert);
    } catch (e) {
      if (!mounted) return;
      _afficherMessage(e.toString().replaceFirst('Exception: ', ''), rouge);
    }
    await chargerActivites();
  }

  // Demande confirmation puis annule toute la participation
  Future<void> seDesinscrire(_ActiviteAvecInscrits element) async {
    final activite = element.activite;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler votre participation ?'),
        content: Text(
          'Vos ${element.mesPersonnes} personne(s) seront retirées de cette '
          'activité. La participation des autres employés n\'est pas modifiée.',
        ),
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
        activite.id!,
        UtilisateurCourant.id,
      );
      if (!mounted) return;
      _afficherMessage('Participation annulée', vert);
    } catch (e) {
      if (!mounted) return;
      _afficherMessage(e.toString().replaceFirst('Exception: ', ''), rouge);
    }
    await chargerActivites();
  }

  // Construit la zone du bas de la carte : bouton selon la situation
  Widget _zoneParticipation(_ActiviteAvecInscrits element, bool complet) {
    // Cas 1 : l'utilisateur participe déjà
    if (element.participe) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: vert),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Vous participez (${element.mesPersonnes} personne(s))',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Modifier le nombre de personnes
              Expanded(
                child: OutlinedButton(
                  onPressed: () => modifierParticipation(element),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: violet,
                    side: const BorderSide(color: violet),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Modifier ma participation'),
                ),
              ),
              const SizedBox(width: 8),
              // Annuler toute la participation
              TextButton(
                onPressed: () => seDesinscrire(element),
                style: TextButton.styleFrom(foregroundColor: rouge),
                child: const Text('Annuler ma participation'),
              ),
            ],
          ),
        ],
      );
    }

    // Cas 2 et 3 : bouton pleine largeur (grisé si l'activité est complète)
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: complet ? null : () => participer(element),
        style: ElevatedButton.styleFrom(
          backgroundColor: violet,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(complet ? 'Complet' : 'Participer'),
      ),
    );
  }

  // Construit la carte d'une activité
  Widget _carteActivite(_ActiviteAvecInscrits element) {
    final activite = element.activite;
    final inscrits = element.inscrits;
    final complet = inscrits >= activite.capaciteMax;
    final restantes = activite.capaciteMax - inscrits;
    // Valeur entre 0 et 1 pour la barre de progression
    final progression = activite.capaciteMax > 0
        ? (inscrits / activite.capaciteMax).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre + catégorie
            Row(
              children: [
                Expanded(
                  child: Text(
                    activite.titre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(activite.categorie),
                  backgroundColor: violet.withValues(alpha: 0.12),
                  labelStyle: const TextStyle(color: violet),
                  side: BorderSide.none,
                ),
                // Crayon : modifier l'activité
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => ouvrirFormulaire(activite),
                ),
                // Corbeille : supprimer l'activité
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => supprimerActivite(activite),
                ),
              ],
            ),
            // Horaires
            Text('${activite.heureDebut} - ${activite.heureFin}'),
            const SizedBox(height: 12),
            // Places : texte + barre
            Text('$inscrits / ${activite.capaciteMax} places'),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: progression,
              color: violet,
              backgroundColor: violet.withValues(alpha: 0.15),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 10),
            // Badge "Complet" ou nombre de places restantes
            if (complet)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: rouge,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Complet',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Text(
                '$restantes places restantes',
                style: const TextStyle(
                  color: vert,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 12),
            // Bouton Participer / Se désinscrire / Complet
            _zoneParticipation(element, complet),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final evenement = widget.evenement;

    return Scaffold(
      backgroundColor: fond,
      appBar: AppBar(title: Text(evenement.titre)),
      // Toute la page défile (infos en haut, activités en dessous)
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Photo de l'événement
          ImageEvenement(image: evenement.image, height: 180),
          // Rappel discret de l'employé connecté (seulement en développement)
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Connecté en tant que : ${UtilisateurCourant.nom()}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  evenement.titre,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: violet),
                    const SizedBox(width: 6),
                    Text(evenement.date),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.place, size: 16, color: violet),
                    const SizedBox(width: 6),
                    Expanded(child: Text(evenement.lieu)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(evenement.description),
                const SizedBox(height: 24),
                const Text(
                  'Activités',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                // Bouton pour ajouter une activité
                ElevatedButton.icon(
                  onPressed: () => ouvrirFormulaire(),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une activité'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: violet,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_chargement)
                  const Center(child: CircularProgressIndicator())
                else if (_activites.isEmpty)
                  const Text('Aucune activité pour cet événement')
                else
                  ..._activites.map(_carteActivite),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
