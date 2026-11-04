import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../entities/evenement.dart';
import '../services/evenement_service.dart';
import 'image_evenement.dart';

class EvenementFormScreen extends StatefulWidget {
  // null = création, sinon modification
  final Evenement? evenement;

  const EvenementFormScreen({super.key, this.evenement});

  @override
  State<EvenementFormScreen> createState() => _EvenementFormScreenState();
}

class _EvenementFormScreenState extends State<EvenementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final EvenementService _evenementService = EvenementService();

  late final TextEditingController _titreController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _dateController;
  late final TextEditingController _lieuController;
  // Chemin de la photo de l'événement (null = pas de photo)
  String? _image;

  @override
  void initState() {
    super.initState();
    // Pré-remplit les champs si on modifie
    final e = widget.evenement;
    _titreController = TextEditingController(text: e?.titre ?? '');
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _dateController = TextEditingController(text: e?.date ?? '');
    _lieuController = TextEditingController(text: e?.lieu ?? '');
    // En modification : on affiche la photo déjà enregistrée
    _image = e?.image;
  }

  @override
  void dispose() {
    _titreController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _lieuController.dispose();
    super.dispose();
  }

  // Ouvre la galerie du téléphone et garde une copie de la photo choisie
  Future<void> choisirPhoto() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 80,
      );
      // L'utilisateur a fermé la galerie sans choisir
      if (photo == null) return;

      // Dossier de l'application : .../evenements_images
      final dossierApp = await getApplicationDocumentsDirectory();
      final dossierImages =
          Directory(p.join(dossierApp.path, 'evenements_images'));
      if (!await dossierImages.exists()) {
        await dossierImages.create(recursive: true);
      }

      // Nom unique : l'heure actuelle en millisecondes + l'extension d'origine
      final extension = p.extension(photo.path);
      final nomFichier = '${DateTime.now().millisecondsSinceEpoch}$extension';
      final cheminCopie = p.join(dossierImages.path, nomFichier);

      // Copie la photo dans le dossier de l'application
      await File(photo.path).copy(cheminCopie);

      if (!mounted) return;
      setState(() {
        _image = cheminCopie;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'importer la photo")),
      );
    }
  }

  // Enregistre l'événement (ajout ou modification)
  Future<void> enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    final evenement = Evenement(
      id: widget.evenement?.id,
      titre: _titreController.text.trim(),
      description: _descriptionController.text.trim(),
      date: _dateController.text.trim(),
      lieu: _lieuController.text.trim(),
      image: _image,
    );

    if (widget.evenement == null) {
      await _evenementService.ajouter(evenement);
    } else {
      await _evenementService.modifier(evenement);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.evenement == null
            ? 'Nouvel événement'
            : "Modifier l'événement"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          // 32 px en bas pour que le bouton "Enregistrer" reste accessible
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _titreController,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez saisir le titre';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez saisir la description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    hintText: 'AAAA-MM-JJ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez saisir la date';
                    }
                    final texte = value.trim();
                    // Format AAAA-MM-JJ et date réelle
                    final format = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                    final date = DateTime.tryParse(texte);
                    if (!format.hasMatch(texte) || date == null) {
                      return 'Format invalide (exemple : 2030-10-12)';
                    }
                    // Refuse les dates impossibles (ex : 2030-02-31)
                    final mois = date.month.toString().padLeft(2, '0');
                    final jour = date.day.toString().padLeft(2, '0');
                    if ('${date.year}-$mois-$jour' != texte) {
                      return 'Date invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lieuController,
                  decoration: const InputDecoration(
                    labelText: 'Lieu',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez saisir le lieu';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Photo de l'événement"),
                ),
                const SizedBox(height: 8),
                // Bouton pour choisir une photo dans la galerie (facultatif)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: choisirPhoto,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Choisir une photo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7F5AF0),
                      side: const BorderSide(color: Color(0xFF7F5AF0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                // Aperçu de la photo, avec une croix pour la retirer
                if (_image != null) ...[
                  const SizedBox(height: 12),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ImageEvenement(image: _image, height: 160),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          tooltip: 'Retirer la photo',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _image = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: enregistrer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7F5AF0),
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
      ),
    );
  }
}
