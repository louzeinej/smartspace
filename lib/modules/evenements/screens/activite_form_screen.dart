import 'package:flutter/material.dart';
import '../entities/activite.dart';
import '../services/activite_service.dart';

// Formulaire pour créer ou modifier une activité
// - activite == null : création
// - activite fournie : modification (champs pré-remplis)
class ActiviteFormScreen extends StatefulWidget {
  final int evenementId;
  final Activite? activite;

  const ActiviteFormScreen({
    super.key,
    required this.evenementId,
    this.activite,
  });

  @override
  State<ActiviteFormScreen> createState() => _ActiviteFormScreenState();
}

class _ActiviteFormScreenState extends State<ActiviteFormScreen> {
  // Couleurs de la charte
  static const Color violet = Color(0xFF7F5AF0);
  static const Color fond = Color(0xFFF7F7FB);
  static const Color rouge = Color(0xFFFF6B6B);

  static const List<String> categories = [
    'Danse',
    'Peinture',
    'Sport',
    'Formation',
    'Musique',
    'Autre',
  ];

  final _formKey = GlobalKey<FormState>();
  final ActiviteService _activiteService = ActiviteService();

  late final TextEditingController _titreController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _heureDebutController;
  late final TextEditingController _heureFinController;
  late final TextEditingController _capaciteController;
  late final TextEditingController _capaciteMinController;
  String? _categorie;
  bool _enregistrement = false;

  bool get _modification => widget.activite != null;

  @override
  void initState() {
    super.initState();
    final a = widget.activite;
    _titreController = TextEditingController(text: a?.titre ?? '');
    _descriptionController = TextEditingController(text: a?.description ?? '');
    _heureDebutController = TextEditingController(text: a?.heureDebut ?? '');
    _heureFinController = TextEditingController(text: a?.heureFin ?? '');
    _capaciteController =
        TextEditingController(text: a != null ? '${a.capaciteMax}' : '');
    // Minimum de participants : 0 par défaut
    _capaciteMinController =
        TextEditingController(text: a != null ? '${a.capaciteMin}' : '0');
    // Si la catégorie enregistrée n'est pas dans la liste, on ne la choisit pas
    if (a != null && categories.contains(a.categorie)) {
      _categorie = a.categorie;
    }
  }

  // Libère les controllers quand l'écran est fermé
  @override
  void dispose() {
    _titreController.dispose();
    _descriptionController.dispose();
    _heureDebutController.dispose();
    _heureFinController.dispose();
    _capaciteController.dispose();
    _capaciteMinController.dispose();
    super.dispose();
  }

  // Transforme "HH:MM" en minutes (null si le format est invalide)
  int? _enMinutes(String texte) {
    final correspondance =
        RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(texte.trim());
    if (correspondance == null) return null;
    return int.parse(correspondance.group(1)!) * 60 +
        int.parse(correspondance.group(2)!);
  }

  // Vérifie une heure obligatoire au format HH:MM
  String? _verifierHeure(String? valeur, String nom) {
    if (valeur == null || valeur.trim().isEmpty) {
      return 'Veuillez saisir l\'heure de $nom';
    }
    if (_enMinutes(valeur) == null) {
      return 'Format invalide (HH:MM, de 00:00 à 23:59)';
    }
    return null;
  }

  // Enregistre l'activité (ajout ou modification)
  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enregistrement = true);

    final activite = Activite(
      id: widget.activite?.id,
      evenementId: widget.evenementId,
      titre: _titreController.text.trim(),
      description: _descriptionController.text.trim(),
      heureDebut: _heureDebutController.text.trim(),
      heureFin: _heureFinController.text.trim(),
      capaciteMax: int.parse(_capaciteController.text.trim()),
      capaciteMin: int.tryParse(_capaciteMinController.text.trim()) ?? 0,
      categorie: _categorie!,
    );

    try {
      if (_modification) {
        await _activiteService.modifier(activite);
      } else {
        await _activiteService.ajouter(activite);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enregistrement = false);
      // On affiche le message d'erreur sans fermer l'écran
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: rouge, content: Text(message)),
      );
    }
  }

  // Style commun des champs (arrondis)
  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: violet, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fond,
      appBar: AppBar(
        title: Text(_modification ? 'Modifier l\'activité' : 'Nouvelle activité'),
      ),
      body: SingleChildScrollView(
        // 32 px en bas pour que le bouton "Enregistrer" reste accessible
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titreController,
                decoration: _decoration('Titre'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Veuillez saisir le titre'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: _decoration('Description'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Veuillez saisir la description'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _heureDebutController,
                keyboardType: TextInputType.datetime,
                decoration: _decoration('Heure de début', hint: 'HH:MM (ex : 08:00)'),
                validator: (v) => _verifierHeure(v, 'début'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _heureFinController,
                keyboardType: TextInputType.datetime,
                decoration: _decoration('Heure de fin', hint: 'HH:MM (ex : 10:00)'),
                validator: (v) {
                  final erreur = _verifierHeure(v, 'fin');
                  if (erreur != null) return erreur;
                  // L'heure de fin doit être après l'heure de début
                  final debut = _enMinutes(_heureDebutController.text);
                  final fin = _enMinutes(v!);
                  if (debut != null && fin != null && fin <= debut) {
                    return 'L\'heure de fin doit être après l\'heure de début';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capaciteController,
                keyboardType: TextInputType.number,
                decoration: _decoration('Capacité maximale'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Veuillez saisir la capacité maximale';
                  }
                  final nombre = int.tryParse(v.trim());
                  if (nombre == null || nombre <= 0) {
                    return 'La capacité doit être un entier supérieur à 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capaciteMinController,
                keyboardType: TextInputType.number,
                decoration: _decoration('Minimum de participants (0 = aucun)'),
                validator: (v) {
                  final nombre = int.tryParse((v ?? '').trim());
                  if (nombre == null || nombre < 0) {
                    return 'Le minimum doit être un entier supérieur ou égal à 0';
                  }
                  // Le minimum ne dépasse pas la capacité maximale
                  final max = int.tryParse(_capaciteController.text.trim());
                  if (max != null && nombre > max) {
                    return 'Le minimum ne peut pas dépasser la capacité maximale';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _categorie,
                decoration: _decoration('Catégorie'),
                items: categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (valeur) => setState(() => _categorie = valeur),
                validator: (v) =>
                    v == null ? 'Veuillez choisir la catégorie' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _enregistrement ? null : _enregistrer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: violet,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
