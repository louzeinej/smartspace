import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../entities/activite.dart';
import '../entities/evenement.dart';
import '../entities/regles_participation.dart';
import '../entities/statut_activite.dart';
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
  // Titre de l'activité en conflit d'horaires (null = pas de conflit)
  final String? conflit;

  _ActiviteAvecInscrits(
    this.activite,
    this.inscrits,
    this.mesPersonnes,
    this.conflit,
  );

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
  // true si le maximum vient de la règle "personnes par inscription"
  // (et non du nombre de places restantes)
  final bool limiteParRegle;

  const ChoixNombrePersonnes({
    super.key,
    required this.maximum,
    this.initial = 1,
    this.minimum = 1,
    this.titre = 'Combien de personnes participent ?',
    this.limiteParRegle = false,
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
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
                style:
                    const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
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
          // Explique d'où vient le maximum
          Text(
            widget.limiteParRegle
                ? 'Maximum $maxPersonnesParInscription personnes par inscription'
                : 'Maximum : ${widget.maximum} place(s) restante(s)',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
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
  static const Color orange = Color(0xFFF5A623);
  static const Color rougeFonce = Color(0xFFC0392B);

  final ActiviteService _activiteService = ActiviteService();
  final ParticipationService _participationService = ParticipationService();
  List<_ActiviteAvecInscrits> _activites = [];
  bool _chargement = true;
  // Contrôle le défilement de la page (utilisé aussi par la barre de défilement)
  late final ScrollController _scrollController;
  // Quels boutons de défilement sont visibles ?
  bool _montrerHaut = false;
  bool _montrerBas = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_majBoutonsDefilement);
    chargerActivites();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_majBoutonsDefilement);
    _scrollController.dispose();
    super.dispose();
  }

  // Met à jour la visibilité des boutons ↑ et ↓ selon la position de la page
  void _majBoutonsDefilement() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final haut = position.pixels > 100;
    final bas = position.pixels < position.maxScrollExtent - 20;
    // On redessine seulement si une valeur change
    if (haut != _montrerHaut || bas != _montrerBas) {
      setState(() {
        _montrerHaut = haut;
        _montrerBas = bas;
      });
    }
  }

  // Remonte tout en haut de la page
  void _allerEnHaut() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  // Descend d'environ 350 px (sans dépasser le bas de la page)
  void _descendre() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      min(
        _scrollController.offset + 350,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
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
        final mesPersonnes = await _participationService
            .nombrePersonnesInscrites(activite.id!, UtilisateurCourant.id);
        // Conflit d'horaires : seulement si l'utilisateur ne participe pas
        String? conflit;
        if (mesPersonnes == 0) {
          conflit = await _participationService.trouverConflitHoraire(
            activite.id!,
            UtilisateurCourant.id,
          );
        }
        resultat.add(
          _ActiviteAvecInscrits(activite, inscrits, mesPersonnes, conflit),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _activites = resultat;
      _chargement = false;
    });
    // Une fois la page dessinée, on regarde s'il y a du contenu en dessous
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _majBoutonsDefilement();
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(backgroundColor: couleur, content: Text(texte)));
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
        builder: (context) => ChoixNombrePersonnes(
          // Le plus petit entre les places restantes et la limite par inscription
          maximum: min(restantes, maxPersonnesParInscription),
          limiteParRegle: restantes > maxPersonnesParInscription,
        ),
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
    // Places pour ce groupe = nombre actuel + places encore libres
    final placesGroupe = element.mesPersonnes + restantes;
    // Maximum = le plus petit entre ces places et la limite par inscription
    final maximum = min(placesGroupe, maxPersonnesParInscription);

    final choix = await showDialog<int>(
      context: context,
      builder: (context) => ChoixNombrePersonnes(
        titre: 'Modifier le nombre de personnes',
        initial: element.mesPersonnes,
        maximum: maximum,
        limiteParRegle: placesGroupe > maxPersonnesParInscription,
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

  // Ligne d'information sur le minimum de participants
  Widget _ligneMinimum(int minimum, int inscrits, StatutActivite statut) {
    final IconData icone;
    final Color couleur;
    final String texte;
    if (statut == StatutActivite.annulee) {
      icone = Icons.cancel;
      couleur = rougeFonce;
      texte = 'Activité annulée : minimum de $minimum personnes non atteint';
    } else if (inscrits >= minimum) {
      icone = Icons.check_circle;
      couleur = vert;
      texte = 'Minimum atteint : activité confirmée';
    } else {
      icone = Icons.warning_amber;
      couleur = orange;
      texte = 'Pas assez de participants : minimum requis $minimum personnes '
          '(il en manque ${minimum - inscrits})';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 12, color: couleur),
          const SizedBox(width: 4),
          Expanded(
            child: Text(texte, style: TextStyle(fontSize: 12, color: couleur)),
          ),
        ],
      ),
    );
  }

  // Construit la zone du bas de la carte : bouton selon la situation
  Widget _zoneParticipation(
    _ActiviteAvecInscrits element,
    StatutActivite statut,
  ) {
    // Activité annulée et l'utilisateur y était inscrit : pas de boutons
    if (element.participe && statut == StatutActivite.annulee) {
      return const Row(
        children: [
          Icon(Icons.cancel, color: rougeFonce),
          SizedBox(width: 6),
          Expanded(child: Text('Activité annulée')),
        ],
      );
    }

    // Cas 0 : activité terminée et l'utilisateur y a participé : pas de boutons
    if (element.participe && statut == StatutActivite.terminee) {
      return const Row(
        children: [
          Icon(Icons.check_circle, color: vert),
          SizedBox(width: 6),
          Expanded(child: Text('Vous avez participé')),
        ],
      );
    }

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

    // Texte du bouton, par ordre de priorité :
    // inscriptions fermées, complet, conflit d'horaires, sinon Participer
    final conflit = element.conflit;
    final ferme =
        statut == StatutActivite.terminee || statut == StatutActivite.enCours;
    final complet = statut == StatutActivite.complete;
    final annulee = statut == StatutActivite.annulee;
    final bloque = annulee || ferme || complet || conflit != null;
    final texte = annulee
        ? 'Activité annulée'
        : (ferme
            ? 'Inscriptions fermées'
            : (complet
                ? 'Complet'
                : (conflit != null ? "Conflit d'horaires" : 'Participer')));

    // Cas 2 et 3 : bouton pleine largeur (grisé si on ne peut pas participer)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: bloque ? null : () => participer(element),
            style: ElevatedButton.styleFrom(
              backgroundColor: violet,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(texte),
          ),
        ),
        // Explication du conflit sous le bouton
        if (conflit != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Vous participez déjà à « $conflit » sur ce créneau.',
              style: const TextStyle(color: rouge, fontSize: 12),
            ),
          ),
      ],
    );
  }

  // Construit la carte d'une activité
  Widget _carteActivite(_ActiviteAvecInscrits element) {
    final activite = element.activite;
    final inscrits = element.inscrits;
    // Statut automatique de l'activité
    final statut = calculerStatut(
      dateEvenement: widget.evenement.date,
      heureDebut: activite.heureDebut,
      heureFin: activite.heureFin,
      capaciteMax: activite.capaciteMax,
      inscrits: inscrits,
      capaciteMin: activite.capaciteMin,
    );
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
                // Badge du statut
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
                const SizedBox(width: 6),
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
            Text(
              '$inscrits / ${activite.capaciteMax} places '
              '(${pourcentageOccupation(inscrits, activite.capaciteMax)} %)',
            ),
            // Info sur le minimum de participants (seulement s'il y en a un)
            if (activite.capaciteMin > 0)
              _ligneMinimum(activite.capaciteMin, inscrits, statut),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: progression,
              color: violet,
              backgroundColor: violet.withValues(alpha: 0.15),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 10),
            // Nombre de places restantes
            Text(
              '$restantes places restantes',
              style: const TextStyle(
                color: vert,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // Bouton Participer / Se désinscrire / Inscriptions fermées...
            _zoneParticipation(element, statut),
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
      // Boutons de défilement par simple clic
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_montrerHaut)
            FloatingActionButton.small(
              heroTag: 'detail_defiler_haut',
              backgroundColor: violet,
              foregroundColor: Colors.white,
              onPressed: _allerEnHaut,
              child: const Icon(Icons.arrow_upward),
            ),
          if (_montrerHaut && _montrerBas) const SizedBox(height: 8),
          if (_montrerBas)
            FloatingActionButton.small(
              heroTag: 'detail_defiler_bas',
              backgroundColor: violet,
              foregroundColor: Colors.white,
              onPressed: _descendre,
              child: const Icon(Icons.arrow_downward),
            ),
        ],
      ),
      // Toute la page défile (infos en haut, activités en dessous)
      body: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          // Grand espace en bas : la dernière carte reste visible en entier
          padding: const EdgeInsets.only(bottom: 96),
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
      ),
    );
  }
}
