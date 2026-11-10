import 'package:flutter_test/flutter_test.dart';
import 'package:smartspace/models/user_role.dart';
import 'package:smartspace/projets/models/projet.dart';
import 'package:smartspace/projets/services/projet_access.dart';

void main() {
  group('peutCreerProjet', () {
    test('Scrum Master et Administrateur uniquement', () {
      final autorises =
          UserRole.values.where(ProjetAccess.peutCreerProjet).toSet();
      expect(autorises, {UserRole.scrumMaster, UserRole.administrateur});
    });
  });

  group('peutGererProjet', () {
    const projet = Projet(
        titre: 'P', description: 'D', dateCreation: '2026-01-01', createurId: 7);
    const orphelin =
        Projet(titre: 'P', description: 'D', dateCreation: '2026-01-01');

    test('le créateur peut gérer son projet', () {
      expect(
          ProjetAccess.peutGererProjet(projet, utilisateurId: 7, estAdmin: false),
          isTrue);
    });

    test('un autre utilisateur ne peut pas', () {
      expect(
          ProjetAccess.peutGererProjet(projet, utilisateurId: 8, estAdmin: false),
          isFalse);
    });

    test('un administrateur peut gérer le projet d\'un autre', () {
      expect(
          ProjetAccess.peutGererProjet(projet, utilisateurId: 8, estAdmin: true),
          isTrue);
    });

    test('créateur supprimé : réservé aux administrateurs', () {
      expect(
          ProjetAccess.peutGererProjet(orphelin,
              utilisateurId: 0, estAdmin: false),
          isFalse);
      expect(
          ProjetAccess.peutGererProjet(orphelin,
              utilisateurId: 0, estAdmin: true),
          isTrue);
    });
  });
}
