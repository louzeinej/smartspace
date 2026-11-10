import 'package:flutter/material.dart';

import '../models/reservation.dart';
import '../models/salle.dart';
import '../services/jours_feries_service.dart';
import '../services/reservation_service.dart';
import '../ui/smartspace_style.dart';

/// Modification d'une réservation existante : objet, participants, date,
/// créneau et salle. La disponibilité est revérifiée par le service
/// (transaction, en ignorant la réservation modifiée elle-même).
class ModifierReservationScreen extends StatefulWidget {
  const ModifierReservationScreen({
    super.key,
    required this.service,
    required this.reservation,
    this.joursFeries,
  });
  final ReservationService service;
  final Reservation reservation;
  final JoursFeriesService? joursFeries;

  @override
  State<ModifierReservationScreen> createState() => _ModifierReservationScreenState();
}

class _ModifierReservationScreenState extends State<ModifierReservationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _objet = TextEditingController(text: widget.reservation.objet);
  late final _nb =
      TextEditingController(text: widget.reservation.nbPersonnes.toString());
  late DateTime _date = lireDate(widget.reservation.date);
  late TimeOfDay _debut = lireHeure(widget.reservation.heureDebut);
  late TimeOfDay _fin = lireHeure(widget.reservation.heureFin);
  late int _salleId = widget.reservation.salleId;

  late final Future<List<Salle>> _salles = widget.service.getSalles();
  late final JoursFeriesService _feries = widget.joursFeries ?? JoursFeriesService();
  String? _jourFerie;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _verifierJourFerie();
  }

  @override
  void dispose() {
    _objet.dispose();
    _nb.dispose();
    super.dispose();
  }

  Future<void> _verifierJourFerie() async {
    final date = formatDate(_date);
    final nom = await _feries.jourFerie(date);
    if (mounted && formatDate(_date) == date) setState(() => _jourFerie = nom);
  }

  Future<void> _choisirDate() async {
    final now = DateTime.now();
    final premier = DateTime(now.year, now.month, now.day);
    final d = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(premier) ? premier : _date,
      firstDate: premier,
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

  Future<void> _enregistrer() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (formatHeure(_debut).compareTo(formatHeure(_fin)) >= 0) {
      ssMessage(context, 'L\'heure de fin doit être après l\'heure de début', erreur: true);
      return;
    }
    final debutComplet =
        DateTime(_date.year, _date.month, _date.day, _debut.hour, _debut.minute);
    if (debutComplet.isBefore(DateTime.now())) {
      ssMessage(context, 'Ce créneau est déjà passé', erreur: true);
      return;
    }
    setState(() => _enCours = true);
    try {
      await widget.service.modifierReservation(Reservation(
        id: widget.reservation.id,
        salleId: _salleId,
        utilisateurId: widget.reservation.utilisateurId,
        objet: _objet.text.trim(),
        date: formatDate(_date),
        heureDebut: formatHeure(_debut),
        heureFin: formatHeure(_fin),
        nbPersonnes: int.parse(_nb.text.trim()),
      ));
      if (!mounted) return;
      ssMessage(context, 'Réservation modifiée');
      Navigator.pop(context, true);
    } on ReservationException catch (e) {
      if (mounted) ssMessage(context, e.message, erreur: true);
    } finally {
      if (mounted) setState(() => _enCours = false);
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
    return Scaffold(
      backgroundColor: SsColors.fond,
      appBar: AppBar(
        backgroundColor: SsColors.primaire,
        foregroundColor: Colors.white,
        title: const Text('Modifier la réservation'),
      ),
      body: FutureBuilder<List<Salle>>(
        future: _salles,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Erreur : ${snap.error}'));
          final salles = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Form(
                key: _formKey,
                child: Column(children: [
                  TextFormField(
                    controller: _objet,
                    decoration: ssChamp('Objet', icone: Icons.notes),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Indiquez l\'objet' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nb,
                    keyboardType: TextInputType.number,
                    decoration:
                        ssChamp('Nombre de participants', icone: Icons.groups_outlined),
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      if (n == null) return 'Entrez un nombre';
                      if (n <= 0) return 'Au moins 1 participant';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: salles.any((s) => s.id == _salleId) ? _salleId : null,
                    decoration: ssChamp('Salle', icone: Icons.meeting_room_outlined),
                    items: [
                      for (final s in salles)
                        DropdownMenuItem(
                          value: s.id,
                          child: Text('Salle ${s.numero} · ${s.emplacement} · '
                              '${s.capacite} places'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _salleId = v ?? _salleId),
                    validator: (v) => v == null ? 'Choisissez une salle' : null,
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
                  SsBoutonPrincipal(
                    label: _enCours ? 'Enregistrement…' : 'Enregistrer les modifications',
                    onPressed: _enCours ? null : _enregistrer,
                  ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}
