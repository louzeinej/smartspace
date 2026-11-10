import 'dart:math';

import 'package:flutter/material.dart';
import '../services/statistiques_service.dart';

// Écran de statistiques de participation.
// À restreindre au rôle Administrateur quand le module utilisateurs sera branché.
class StatistiquesScreen extends StatefulWidget {
  const StatistiquesScreen({super.key});

  @override
  State<StatistiquesScreen> createState() => _StatistiquesScreenState();
}

class _StatistiquesScreenState extends State<StatistiquesScreen> {
  // Couleurs de la charte
  static const Color violet = Color(0xFF7F5AF0);
  static const Color fond = Color(0xFFF7F7FB);

  final StatistiquesService _service = StatistiquesService();
  late Future<List<Object>> _chargement;
  // Contrôle le défilement de la page
  late final ScrollController _scrollController;
  // Quels boutons de défilement sont visibles ?
  bool _montrerHaut = false;
  bool _montrerBas = false;

  @override
  void initState() {
    super.initState();
    _chargement = _charger();
    _scrollController = ScrollController();
    _scrollController.addListener(_majBoutonsDefilement);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_majBoutonsDefilement);
    _scrollController.dispose();
    super.dispose();
  }

  // Met à jour la visibilité des boutons ↑ et ↓ selon la position de la page
  void _majBoutonsDefilement() {
    if (!mounted || !_scrollController.hasClients) return;
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

  // Charge les trois séries de statistiques en même temps
  Future<List<Object>> _charger() {
    return Future.wait<Object>([
      _service.chiffresCles(),
      _service.parCategorie(),
      _service.topActivites(limite: 5),
    ]);
  }

  // "1 participant" ou "N participants"
  String _texteParticipants(int n) {
    return n <= 1 ? '$n participant' : '$n participants';
  }

  // Pourcentage entier (0 si on divise par zéro)
  int _pourcentage(int partie, int total) {
    if (total <= 0) return 0;
    return (partie * 100 / total).round();
  }

  // Titre d'une section
  Widget _titre(String texte) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        texte,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Une carte de chiffre : icône, grand chiffre violet, libellé gris
  Widget _carteChiffre(IconData icone, String valeur, String libelle) {
    return Card(
      color: Colors.white,
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, color: violet, size: 20),
            const SizedBox(height: 4),
            Text(
              valeur,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: violet,
              ),
            ),
            Text(
              libelle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // Une ligne de la liste des catégories
  Widget _ligneCategorie(Map<String, Object?> ligne, int totalMax) {
    final total = ligne['total'] as int;
    // La catégorie la plus populaire est à 100 %
    final valeur = totalMax > 0 ? total / totalMax : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ligne['categorie'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(_texteParticipants(total)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: valeur,
            color: violet,
            backgroundColor: violet.withValues(alpha: 0.15),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  // Une ligne du classement des activités
  Widget _ligneActivite(int rang, Map<String, Object?> ligne) {
    final total = ligne['total'] as int;
    final capacite = ligne['capacite_max'] as int;
    final pourcentage = _pourcentage(total, capacite);
    final valeur = capacite > 0 ? (total / capacite).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Numéro de classement
          CircleAvatar(
            radius: 14,
            backgroundColor: violet,
            child: Text(
              '$rang',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ligne['titre'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  ligne['evenement'] as String,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text('${_texteParticipants(total)} ($pourcentage %)'),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: valeur,
                  color: violet,
                  backgroundColor: violet.withValues(alpha: 0.15),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Construit tout le contenu une fois les données chargées
  Widget _contenu(
    Map<String, int> chiffres,
    List<Map<String, Object?>> categories,
    List<Map<String, Object?>> top,
  ) {
    final participants = chiffres['participants'] ?? 0;
    final capaciteTotale = chiffres['capaciteTotale'] ?? 0;
    final taux = _pourcentage(participants, capaciteTotale);

    // Maximum 5 catégories ; la première sert de référence (100 %)
    final categoriesAffichees = categories.take(5).toList();
    final totalMax = categoriesAffichees.isEmpty
        ? 0
        : categoriesAffichees.first['total'] as int;

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      // Grand espace en bas : le dernier contenu reste visible en entier
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        const Text(
          'Tableau de bord des activités',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        // Les 4 chiffres clés
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: [
            _carteChiffre(
              Icons.people,
              '$participants',
              'Participants au total',
            ),
            _carteChiffre(
              Icons.event_available,
              '${chiffres['activites'] ?? 0}',
              'Activités organisées',
            ),
            _carteChiffre(Icons.pie_chart, '$taux %', 'Taux de remplissage'),
            _carteChiffre(
              Icons.block,
              '${chiffres['activitesCompletes'] ?? 0}',
              'Activités complètes',
            ),
          ],
        ),
        if (participants == 0) ...[
          const SizedBox(height: 32),
          const Center(child: Text('Aucune participation pour le moment')),
        ] else ...[
          _titre('Catégories les plus populaires'),
          ...categoriesAffichees.map((ligne) => _ligneCategorie(ligne, totalMax)),
          _titre('Activités les plus populaires'),
          Card(
            color: Colors.white,
            elevation: 1,
            margin: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < top.length; i++)
                    _ligneActivite(i + 1, top[i]),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fond,
      appBar: AppBar(
        title: const Text('Statistiques'),
        backgroundColor: violet,
        foregroundColor: Colors.white,
      ),
      // Boutons de défilement par simple clic
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_montrerHaut)
            FloatingActionButton.small(
              heroTag: 'stats_defiler_haut',
              backgroundColor: violet,
              foregroundColor: Colors.white,
              onPressed: _allerEnHaut,
              child: const Icon(Icons.arrow_upward),
            ),
          if (_montrerHaut && _montrerBas) const SizedBox(height: 8),
          if (_montrerBas)
            FloatingActionButton.small(
              heroTag: 'stats_defiler_bas',
              backgroundColor: violet,
              foregroundColor: Colors.white,
              onPressed: _descendre,
              child: const Icon(Icons.arrow_downward),
            ),
        ],
      ),
      body: FutureBuilder<List<Object>>(
        future: _chargement,
        builder: (context, snapshot) {
          // Pendant le chargement
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          // Si le chargement a échoué
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Impossible de charger les statistiques. '
                  'Veuillez réessayer plus tard.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final donnees = snapshot.data!;
          // Après l'affichage des données, on regarde s'il y a du contenu
          // en dessous (pas de setState pendant le build)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _majBoutonsDefilement();
          });
          return _contenu(
            donnees[0] as Map<String, int>,
            donnees[1] as List<Map<String, Object?>>,
            donnees[2] as List<Map<String, Object?>>,
          );
        },
      ),
    );
  }
}
