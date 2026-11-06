import 'package:flutter/material.dart';

import '../models/salle.dart';
import '../services/reservation_service.dart';
import '../ui/smartspace_style.dart';

/// Ajout ou modification d'une salle (administrateur).
class SalleFormScreen extends StatefulWidget {
  const SalleFormScreen({super.key, required this.service, this.salle});
  final ReservationService service;
  final Salle? salle;

  @override
  State<SalleFormScreen> createState() => _SalleFormScreenState();
}

class _SalleFormScreenState extends State<SalleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _numero = TextEditingController(text: widget.salle?.numero);
  late final _emplacement = TextEditingController(text: widget.salle?.emplacement);
  late final _capacite =
      TextEditingController(text: widget.salle?.capacite.toString());
  bool _enCours = false;

  bool get _modification => widget.salle != null;

  @override
  void dispose() {
    _numero.dispose();
    _emplacement.dispose();
    _capacite.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enCours = true);
    final salle = Salle(
      id: widget.salle?.id,
      numero: _numero.text.trim(),
      emplacement: _emplacement.text.trim(),
      capacite: int.parse(_capacite.text.trim()),
    );
    try {
      if (_modification) {
        await widget.service.modifierSalle(salle);
      } else {
        await widget.service.ajouterSalle(salle);
      }
      if (!mounted) return;
      ssMessage(context, _modification ? 'Salle modifiée' : 'Salle ajoutée');
      Navigator.pop(context, true);
    } on ReservationException catch (e) {
      if (mounted) ssMessage(context, e.message, erreur: true);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SsColors.fond,
      appBar: AppBar(
        backgroundColor: SsColors.primaire,
        foregroundColor: Colors.white,
        title: Text(_modification ? 'Modifier la salle' : 'Nouvelle salle'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _numero,
              decoration: ssChamp('Numéro de salle', icone: Icons.tag),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Le numéro est obligatoire' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emplacement,
              decoration: ssChamp('Emplacement (ex. Bloc A, 2e étage)',
                  icone: Icons.place_outlined),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'L\'emplacement est obligatoire'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _capacite,
              keyboardType: TextInputType.number,
              decoration: ssChamp('Capacité (personnes)', icone: Icons.groups_outlined),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null) return 'Entrez un nombre';
                if (n <= 0) return 'La capacité doit être supérieure à 0';
                if (n > 1000) return 'Capacité trop élevée';
                return null;
              },
            ),
            const SizedBox(height: 24),
            SsBoutonPrincipal(
              label: _enCours ? 'Enregistrement…' : 'Enregistrer',
              onPressed: _enCours ? null : _enregistrer,
            ),
          ],
        ),
      ),
    );
  }
}
