import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../models/publication.dart';
import '../services/networking_service.dart';
import '../ui/networking_style.dart';

/// Feuille modale pour la création ou l'édition d'une publication.
class CreatePublicationSheet extends StatefulWidget {
  const CreatePublicationSheet({
    super.key,
    required this.currentUserId,
    required this.isAdministrator,
    required this.service,
    required this.onCreated,
    this.publicationToEdit,
  });

  final int currentUserId;
  final bool isAdministrator;
  final NetworkingService service;
  final VoidCallback onCreated;
  final Publication? publicationToEdit;

  bool get isEditing => publicationToEdit != null;

  @override
  State<CreatePublicationSheet> createState() => _CreatePublicationSheetState();
}

class _CreatePublicationSheetState extends State<CreatePublicationSheet> {
  final _formKey = GlobalKey<FormState>();

  late String _typeSelectionne;
  late final TextEditingController _titreCtrl;
  late final TextEditingController _contenuCtrl;

  // Pour Formation
  late final TextEditingController _competenceCtrl;
  late final TextEditingController _dateFormationCtrl;

  // Pour Sondage
  late List<TextEditingController> _pollOptionCtrls;

  // Pour Kudos
  List<Map<String, dynamic>> _usersDirectory = [];
  int? _kudosTargetUserId;
  String? _kudosTargetUserName;
  late String _kudosBadgeSelectionne;

  final List<String> _kudosBadges = [
    '🌟 Esprit d\'équipe',
    '💡 Innovation',
    '🚀 Leadership',
    '🎨 Excellence UI/UX',
    '🛠️ Résolution de Problèmes',
    '🤝 Entraide & Bienveillance',
  ];

  late bool _isPinned;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final pub = widget.publicationToEdit;

    _typeSelectionne = pub?.type ?? PublicationType.actualite;
    _titreCtrl = TextEditingController(text: pub?.titre ?? '');
    _contenuCtrl = TextEditingController(text: pub?.contenu ?? '');

    _competenceCtrl = TextEditingController(text: pub?.formationCompetence ?? '');
    _dateFormationCtrl = TextEditingController(text: pub?.formationDate ?? '');

    _isPinned = pub?.isPinned ?? false;

    _kudosBadgeSelectionne = pub?.kudosBadge ?? _kudosBadges.first;
    _kudosTargetUserId = pub?.kudosDestinataireId;
    _kudosTargetUserName = pub?.kudosDestinataireNom;

    if (pub != null && pub.pollOptions.isNotEmpty) {
      _pollOptionCtrls = pub.pollOptions
          .map((opt) => TextEditingController(text: opt.optionTexte))
          .toList();
    } else {
      _pollOptionCtrls = [
        TextEditingController(text: 'Option 1'),
        TextEditingController(text: 'Option 2'),
      ];
    }

    _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    final users = await widget.service.getAllUsersForKudos();
    if (mounted) {
      setState(() {
        _usersDirectory = users;
        if (_kudosTargetUserId == null && _usersDirectory.isNotEmpty) {
          _kudosTargetUserId = _usersDirectory.first['id'] as int?;
          _kudosTargetUserName = _usersDirectory.first['fullName'] as String?;
        }
      });
    }
  }

  void _addPollOption() {
    if (_pollOptionCtrls.length < 5) {
      setState(() {
        _pollOptionCtrls.add(
          TextEditingController(text: 'Option ${_pollOptionCtrls.length + 1}'),
        );
      });
    }
  }

  void _removePollOption(int index) {
    if (_pollOptionCtrls.length > 2) {
      setState(() {
        _pollOptionCtrls[index].dispose();
        _pollOptionCtrls.removeAt(index);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final nowIso = widget.publicationToEdit?.datePublication ?? DateTime.now().toIso8601String();

      List<String>? pollOptionTexts;
      if (_typeSelectionne == PublicationType.sondage) {
        pollOptionTexts = _pollOptionCtrls.map((c) => c.text.trim()).toList();
      }

      final publication = Publication(
        id: widget.publicationToEdit?.id,
        utilisateurId: widget.publicationToEdit?.utilisateurId ?? widget.currentUserId,
        titre: _titreCtrl.text.trim(),
        contenu: _contenuCtrl.text.trim(),
        type: _typeSelectionne,
        datePublication: nowIso,
        isPinned: widget.isAdministrator && _isPinned,
        likesCount: widget.publicationToEdit?.likesCount ?? 0,
        kudosDestinataireId:
            _typeSelectionne == PublicationType.kudos ? _kudosTargetUserId : null,
        kudosDestinataireNom:
            _typeSelectionne == PublicationType.kudos ? _kudosTargetUserName : null,
        kudosBadge:
            _typeSelectionne == PublicationType.kudos ? _kudosBadgeSelectionne : null,
        formationDate: _typeSelectionne == PublicationType.formation
            ? _dateFormationCtrl.text.trim()
            : null,
        formationCompetence: _typeSelectionne == PublicationType.formation
            ? _competenceCtrl.text.trim()
            : null,
      );

      if (widget.isEditing) {
        await widget.service.updatePublication(
          publication,
          pollOptions: pollOptionTexts,
        );
      } else {
        await widget.service.createPublication(
          publication,
          pollOptions: pollOptionTexts,
        );
      }

      if (mounted) {
        widget.onCreated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? 'Publication mise à jour avec succès !'
                  : 'Publication créée avec succès !',
            ),
            backgroundColor: SsColors.succes,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: SsColors.alerte,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _titreCtrl.dispose();
    _contenuCtrl.dispose();
    _competenceCtrl.dispose();
    _dateFormationCtrl.dispose();
    for (final c in _pollOptionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      widget.isEditing ? Icons.edit_note_rounded : Icons.post_add_rounded,
                      color: SsColors.primaire,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.isEditing ? 'Modifier la Publication' : 'Nouvelle Publication',
                      style: SsText.titreEcran,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Sélecteur de Type de Publication
                const Text('Type de publication :',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: PublicationType.tous.map((type) {
                    final selected = _typeSelectionne == type;
                    final color = PublicationType.colorOf(type);
                    final icon = PublicationType.iconOf(type);

                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 16, color: selected ? Colors.white : color),
                          const SizedBox(width: 6),
                          Text(type),
                        ],
                      ),
                      selected: selected,
                      selectedColor: color,
                      backgroundColor: color.withOpacity(0.1),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : color,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _typeSelectionne = type);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Champ Titre
                TextFormField(
                  controller: _titreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Titre de la publication *',
                    prefixIcon: Icon(Icons.title_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? 'Veuillez saisir un titre' : null,
                ),
                const SizedBox(height: 14),

                // Champ Contenu
                TextFormField(
                  controller: _contenuCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Message / Description *',
                    prefixIcon: Icon(Icons.notes_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty)
                      ? 'Veuillez saisir le contenu'
                      : null,
                ),
                const SizedBox(height: 14),

                // Formulaire spécifique selon le type
                if (_typeSelectionne == PublicationType.formation) _buildFormationFields(),
                if (_typeSelectionne == PublicationType.sondage) _buildPollFields(),
                if (_typeSelectionne == PublicationType.kudos) _buildKudosFields(),

                // Épingler si Admin
                if (widget.isAdministrator) ...[
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Épingler cette annonce en haut du fil',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Visibilité prioritaire pour toute l\'équipe',
                        style: TextStyle(fontSize: 11)),
                    value: _isPinned,
                    activeColor: SsColors.primaire,
                    onChanged: (val) => setState(() => _isPinned = val),
                  ),
                ],

                const SizedBox(height: 20),

                // Bouton Enregistrer
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SsColors.primaire,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Icon(widget.isEditing ? Icons.save_rounded : Icons.send_rounded),
                    label: Text(
                      _isSubmitting
                          ? 'Enregistrement...'
                          : widget.isEditing
                              ? 'Enregistrer les modifications'
                              : 'Publier maintenant',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormationFields() {
    return Column(
      children: [
        TextFormField(
          controller: _competenceCtrl,
          decoration: const InputDecoration(
            labelText: 'Compétence cible / Sujet (ex: Flutter, Design System)',
            prefixIcon: Icon(Icons.verified_rounded),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _dateFormationCtrl,
          decoration: const InputDecoration(
            labelText: 'Date et horaire (ex: Vendredi 14:00 - 16:00)',
            prefixIcon: Icon(Icons.event_rounded),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildPollFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Options du sondage :',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            TextButton.icon(
              onPressed: _addPollOption,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Ajouter option'),
            ),
          ],
        ),
        ..._pollOptionCtrls.asMap().entries.map((entry) {
          final idx = entry.key;
          final ctrl = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: ctrl,
                    decoration: InputDecoration(
                      labelText: 'Option ${idx + 1}',
                      border: const OutlineInputBorder(),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                if (_pollOptionCtrls.length > 2)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: SsColors.alerte),
                    onPressed: () => _removePollOption(idx),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildKudosFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Destinataire du Kudos :',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          value: _kudosTargetUserId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_rounded),
          ),
          items: _usersDirectory.map((u) {
            final roleEnum = UserRole.fromIndex((u['roleIndex'] as int?) ?? 4);
            return DropdownMenuItem<int>(
              value: u['id'] as int,
              child: Text("${u['fullName']} (${roleEnum.label})"),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _kudosTargetUserId = val;
              final found = _usersDirectory.firstWhere((u) => u['id'] == val);
              _kudosTargetUserName = found['fullName'] as String;
            });
          },
        ),
        const SizedBox(height: 12),
        const Text('Badge / Distinction :',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _kudosBadgeSelectionne,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.military_tech_rounded),
          ),
          items: _kudosBadges.map((badge) {
            return DropdownMenuItem<String>(
              value: badge,
              child: Text(badge),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _kudosBadgeSelectionne = val);
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
