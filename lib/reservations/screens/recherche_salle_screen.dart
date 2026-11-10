import 'package:flutter/material.dart';

import '../models/reservation.dart';
import '../models/salle.dart';
import '../services/jours_feries_service.dart';
import '../services/reservation_service.dart';
import '../ui/smartspace_style.dart';

/// Recherche des salles disponibles (date, créneau, capacité) puis réservation.
class RechercheSalleScreen extends StatefulWidget {
  const RechercheSalleScreen({
    super.key,
    required this.service,
    required this.utilisateurId,
    this.onReservee,
    this.joursFeries,
  });
  final ReservationService service;
  final JoursFeriesService? joursFeries;
  final int utilisateurId;
  final VoidCallback? onReservee;

  @override
  State<RechercheSalleScreen> createState() => _RechercheSalleScreenState();
}

class _RechercheSalleScreenState extends State<RechercheSalleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _objet = TextEditingController();
  final _nb = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _debut = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _fin = const TimeOfDay(hour: 10, minute: 0);

  Future<List<SalleResultat>>? _resultats;
  // Critères figés au moment de la recherche (ceux réellement utilisés).
  String? _rDate, _rDebut, _rFin;
  int? _rNb;

  // Valeur ajoutée : jour férié de la date choisie (API Nager.Date).
  late final JoursFeriesService _feries = widget.joursFeries ?? JoursFeriesService();
  String? _jourFerie;

  @override
  void initState() {
    super.initState();
    _verifierJourFerie();
  }

  Future<void> _verifierJourFerie() async {
    final date = formatDate(_date);
    final nom = await _feries.jourFerie(date);
    // Ignore la réponse si l'utilisateur a changé de date entre-temps.
    if (mounted && formatDate(_date) == date) setState(() => _jourFerie = nom);
  }

  @override
  void dispose() {
    _objet.dispose();
    _nb.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null) return;
    setState(() {
      _date = d;
      _jourFerie = null;
    });
    _verifierJourFerie();
  }

  Future<void> _choisirHeure(bool debut) async {
    final t = await showTimePicker(context: context, initialTime: debut ? _debut : _fin);
    if (t == null) return;
    setState(() {
      if (debut) {
        _debut = t;
      } else {
        _fin = t;
      }
    });
  }

  String? _erreurCreneau() {
    if (formatHeure(_debut).compareTo(formatHeure(_fin)) >= 0) {
      return 'L\'heure de fin doit être après l\'heure de début';
    }
    final now = DateTime.now();
    final debutComplet =
        DateTime(_date.year, _date.month, _date.day, _debut.hour, _debut.minute);
    if (debutComplet.isBefore(now)) return 'Ce créneau est déjà passé';
    return null;
  }

  void _rechercher() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final err = _erreurCreneau();
    if (err != null) {
      ssMessage(context, err, erreur: true);
      return;
    }
    setState(() {
      _rDate = formatDate(_date);
      _rDebut = formatHeure(_debut);
      _rFin = formatHeure(_fin);
      _rNb = int.parse(_nb.text.trim());
      _resultats = widget.service.rechercherSalles(
        date: _rDate!,
        heureDebut: _rDebut!,
        heureFin: _rFin!,
        nbPersonnes: _rNb!,
      );
    });
  }

  Future<void> _reserver(Salle salle) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Réserver la salle ${salle.numero} ?'),
        content: Text('${afficherDate(_rDate!)} de $_rDebut à $_rFin\n'
            '${_objet.text.trim()} — $_rNb personne(s)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.service.reserver(Reservation(
        salleId: salle.id!,
        utilisateurId: widget.utilisateurId,
        objet: _objet.text.trim(),
        date: _rDate!,
        heureDebut: _rDebut!,
        heureFin: _rFin!,
        nbPersonnes: _rNb!,
      ));
      if (!mounted) return;
      ssMessage(context, 'Salle ${salle.numero} réservée');
      widget.onReservee?.call();
      _rechercher(); // rafraîchit : la salle n'est plus proposée
    } on ReservationException catch (e) {
      if (mounted) ssMessage(context, e.message, erreur: true);
    }
  }

  Widget _selecteur(IconData icone, String label, String valeur, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: InputDecorator(
          decoration: ssChamp(label, icone: icone),
          child: Text(valeur, style: SsText.courant),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SsColors.fond,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _objet,
                  decoration: ssChamp('Objet (ex. Réunion d\'équipe)', icone: Icons.notes),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Indiquez l\'objet' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nb,
                  keyboardType: TextInputType.number,
                  decoration: ssChamp('Nombre de participants', icone: Icons.groups_outlined),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null) return 'Entrez un nombre';
                    if (n <= 0) return 'Au moins 1 participant';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(children: [
                  _selecteur(Icons.calendar_today_outlined, 'Date',
                      afficherDate(formatDate(_date)), _choisirDate),
                ]),
                if (_jourFerie != null) SsAlerteFerie(nom: _jourFerie!),
                const SizedBox(height: 12),
                Row(children: [
                  _selecteur(Icons.schedule, 'Début', formatHeure(_debut),
                      () => _choisirHeure(true)),
                  const SizedBox(width: 12),
                  _selecteur(Icons.schedule, 'Fin', formatHeure(_fin),
                      () => _choisirHeure(false)),
                ]),
                const SizedBox(height: 20),
                SsBoutonPrincipal(label: 'Rechercher une salle', onPressed: _rechercher),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_resultats != null)
            FutureBuilder<List<SalleResultat>>(
              future: _resultats,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) return Text('Erreur : ${snap.error}');
                final resultats = snap.data!;
                final nbDispo = resultats.where((r) => r.disponible).length;
                if (resultats.isEmpty) {
                  return const SsCarte(
                    child: Row(children: [
                      Icon(Icons.event_busy, color: SsColors.alerte),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                            'Aucune salle assez grande pour ce nombre de participants. '
                            'Ajoutez des salles dans l\'onglet « Salles ».',
                            style: SsText.courant),
                      ),
                    ]),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        nbDispo == 0
                            ? 'Toutes les salles adaptées sont réservées sur ce créneau'
                            : '$nbDispo salle(s) disponible(s)',
                        style: SsText.titreCarte),
                    const SizedBox(height: 10),
                    // shrinkWrap car imbriquée dans le ListView principal.
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: resultats.length,
                      itemBuilder: (context, i) {
                        final res = resultats[i];
                        final s = res.salle;
                        return Opacity(
                          opacity: res.disponible ? 1 : 0.75,
                          child: SsCarte(
                            child: Row(children: [
                              Icon(Icons.meeting_room_outlined,
                                  color: res.disponible
                                      ? SsColors.primaire
                                      : SsColors.alerte),
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
                                        if (!res.disponible)
                                          const SsBadge(
                                              label: 'Réservée', couleur: SsColors.alerte)
                                        else if (i == 0)
                                          const SsBadge(
                                              label: 'Plus adaptée', couleur: SsColors.succes)
                                        else
                                          const SsBadge(
                                              label: 'Disponible', couleur: SsColors.succes),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text('${s.emplacement} · ${s.capacite} places',
                                        style: SsText.secondaire),
                                    if (!res.disponible)
                                      Text('Occupée : ${res.conflit}',
                                          style: SsText.secondaire
                                              .copyWith(color: SsColors.alerte)),
                                  ],
                                ),
                              ),
                              if (res.disponible)
                                TextButton(
                                  onPressed: () => _reserver(s),
                                  child: const Text('Réserver',
                                      style: TextStyle(color: SsColors.primaire)),
                                ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
