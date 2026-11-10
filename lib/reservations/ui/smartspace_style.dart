import 'package:flutter/material.dart';

/// Charte graphique SmartSpace (section 8 du cahier des charges).
class SsColors {
  static const primaire = Color(0xFF7F5AF0);
  static const secondaire = Color(0xFF2D2A4A);
  static const fond = Color(0xFFF7F7FB);
  static const succes = Color(0xFF2ECC71);
  static const alerte = Color(0xFFFF6B6B);
}

class SsText {
  static const titreEcran =
      TextStyle(fontSize: 21, fontWeight: FontWeight.w500, color: SsColors.secondaire);
  static const titreCarte =
      TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: SsColors.secondaire);
  static const courant = TextStyle(fontSize: 14, fontWeight: FontWeight.w400);
  static const secondaire = TextStyle(
      fontSize: 12, fontWeight: FontWeight.w400, color: SsColors.secondaire);
}

/// Bouton principal : dégradé violet, texte blanc, coins 12 px, pleine largeur.
class SsBoutonPrincipal extends StatelessWidget {
  const SsBoutonPrincipal({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final actif = onPressed != null;
    return Opacity(
      opacity: actif ? 1 : 0.5,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
              colors: [SsColors.primaire, Color(0xFF9D7DF5)]),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte : fond blanc, coins 14 px, légère ombre, padding 14 px.
class SsCarte extends StatelessWidget {
  const SsCarte({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(14), child: child),
        ),
      ),
    );
  }
}

/// Badge de statut en forme de pilule.
class SsBadge extends StatelessWidget {
  const SsBadge({super.key, required this.label, required this.couleur});
  final String label;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}

/// Décoration des champs : fond blanc, bordure grise fine, coins 6 px.
InputDecoration ssChamp(String label, {IconData? icone}) {
  OutlineInputBorder bord(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c));
  return InputDecoration(
    labelText: label,
    prefixIcon: icone == null ? null : Icon(icone),
    filled: true,
    fillColor: Colors.white,
    border: bord(Colors.grey.shade300),
    enabledBorder: bord(Colors.grey.shade300),
    focusedBorder: bord(SsColors.primaire),
    errorBorder: bord(SsColors.alerte),
  );
}

void ssMessage(BuildContext context, String texte, {bool erreur = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(texte),
    backgroundColor: erreur ? SsColors.alerte : SsColors.succes,
  ));
}

// ---- Formats de stockage (texte comparable dans SQLite)

String formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String formatHeure(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// yyyy-MM-dd -> DateTime.
DateTime lireDate(String iso) => DateTime.parse(iso);

/// HH:mm -> TimeOfDay.
TimeOfDay lireHeure(String hhmm) {
  final p = hhmm.split(':');
  return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
}

/// Bandeau d'avertissement « jour férié » (donnée de l'API Nager.Date).
class SsAlerteFerie extends StatelessWidget {
  const SsAlerteFerie({super.key, required this.nom});
  final String nom;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x1AFF6B6B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SsColors.alerte),
      ),
      child: Row(children: [
        const Icon(Icons.celebration_outlined, color: SsColors.alerte),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Jour férié : $nom. Vérifiez que les locaux sont ouverts.',
              style: SsText.courant.copyWith(color: SsColors.secondaire)),
        ),
      ]),
    );
  }
}

/// yyyy-MM-dd -> dd/MM/yyyy pour l'affichage.
String afficherDate(String iso) {
  final p = iso.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
}
