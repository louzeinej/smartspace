import 'package:sqflite/sqflite.dart';

import '../../core/database_helper.dart';
import '../../database/user_dao.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../reservations/ui/smartspace_style.dart';
import '../models/projet.dart';
import '../models/statut_tache.dart';
import '../models/tache.dart';
import 'disponibilite_service.dart';
import 'projet_access.dart';

class ProjetException implements Exception {
  final String message;
  ProjetException(this.message);
  @override
  String toString() => message;
}

/// L'utilisateur courant n'a pas le droit d'effectuer cette action.
class AccesRefuseException extends ProjetException {
  AccesRefuseException(super.message);
}

/// L'enregistrement rendrait l'affectation de la tâche invalide.
///
/// Rien n'a été écrit : l'écran peut proposer « Retirer l'affectation et
/// enregistrer ». [conflit] est null si le problème n'est pas une autre tâche.
class ConflitAffectationException extends ProjetException {
  final Tache? conflit;
  ConflitAffectationException(super.message, {this.conflit});
}

/// Candidat à une tâche : la personne et sa disponibilité sur la période.
class Candidat {
  final User utilisateur;
  final Disponibilite disponibilite;
  Candidat(this.utilisateur, this.disponibilite);
}

/// CRUD des projets et des tâches + logique métier : affectation d'une tâche
/// selon le rôle et la disponibilité de la personne.
///
/// Chaque écriture vérifie les droits de l'acteur d'après la ligne en base,
/// jamais d'après l'objet reçu.
class ProjetService {
  ProjetService({
    Future<Database>? database,
    Future<List<User>> Function()? lireUtilisateurs,
    Acteur Function()? acteur,
  })  : _database = database ?? DatabaseHelper.instance.database,
        _lireUtilisateurs = lireUtilisateurs ?? UserDao.instance.getAll,
        _acteur = acteur ?? Acteur.depuisSession;

  final Future<Database> _database;
  final Future<List<User>> Function() _lireUtilisateurs;
  final Acteur Function() _acteur;

  // --------------------------------------------------------------- Projets

  Future<List<Projet>> getProjets() async {
    final db = await _database;
    final rows =
        await db.query('projets', orderBy: 'date_creation DESC, id DESC');
    return rows.map(Projet.fromMap).toList();
  }

  /// Le créateur est toujours l'acteur : les droits en dépendent.
  Future<int> creerProjet(Projet projet) async {
    final acteur = _acteur();
    if (!ProjetAccess.peutCreerProjet(acteur.role)) {
      throw AccesRefuseException(
          'Seuls un Scrum Master ou un administrateur peuvent créer un projet.');
    }
    final db = await _database;
    return db.insert(
        'projets', {...projet.toMap(), 'createur_id': acteur.utilisateurId});
  }

  /// La date de création et le créateur ne changent jamais.
  Future<void> modifierProjet(Projet projet) async {
    final db = await _database;
    await db.transaction((txn) async {
      await _exigerGestion(txn, projet.id!);
      await txn.update(
        'projets',
        {'titre': projet.titre, 'description': projet.description},
        where: 'id = ?',
        whereArgs: [projet.id],
      );
    });
  }

  /// Supprime le projet et ses tâches (ON DELETE CASCADE).
  Future<void> supprimerProjet(int id) async {
    final db = await _database;
    await db.transaction((txn) async {
      await _exigerGestion(txn, id);
      await txn.delete('projets', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---------------------------------------------------------------- Tâches

  Future<List<Tache>> getTachesProjet(int projetId) async {
    final db = await _database;
    final rows = await db.query('taches',
        where: 'projet_id = ?',
        whereArgs: [projetId],
        orderBy: 'date_debut, id');
    return rows.map(Tache.fromMap).toList();
  }

  /// Tâches affectées à [utilisateurId], avec le titre de leur projet.
  Future<List<Tache>> getTachesUtilisateur(int utilisateurId) async {
    final db = await _database;
    return _tachesDe(db, utilisateurId);
  }

  /// Une nouvelle tâche n'est jamais affectée : seul [affecterA] le permet.
  Future<int> creerTache(Tache tache) async {
    _verifierPeriode(tache.dateDebut, tache.dateFin);
    final db = await _database;
    return db.transaction((txn) async {
      await _exigerGestion(txn, tache.projetId);
      return txn.insert('taches', {...tache.toMap(), 'utilisateur_id': null});
    });
  }

  /// N'écrit que les champs du formulaire : le statut et l'affectation
  /// ne changent que par [changerStatut] et [affecterA].
  ///
  /// Si les dates ou le rôle requis changent sur une tâche affectée et non
  /// terminée, l'affectation est revérifiée : en cas de problème, lève
  /// [ConflitAffectationException] sans rien écrire, sauf si
  /// [retirerAffectation] demande explicitement de libérer la tâche.
  Future<void> modifierTache(Tache tache,
      {bool retirerAffectation = false}) async {
    _verifierPeriode(tache.dateDebut, tache.dateFin);
    final utilisateurs = await _utilisateursParId();
    final db = await _database;
    await db.transaction((txn) async {
      final actuelle = await _lireTache(txn, tache.id!);
      await _exigerGestion(txn, actuelle.projetId);

      final periodeOuRoleChange = actuelle.dateDebut != tache.dateDebut ||
          actuelle.dateFin != tache.dateFin ||
          actuelle.roleRequis != tache.roleRequis;
      if (actuelle.estAffectee &&
          !actuelle.statut.estTerminee &&
          periodeOuRoleChange &&
          !retirerAffectation) {
        await _verifierAffectation(
          txn,
          tacheId: actuelle.id!,
          dateDebut: tache.dateDebut,
          dateFin: tache.dateFin,
          roleRequis: tache.roleRequis,
          utilisateur: _trouver(utilisateurs, actuelle.utilisateurId!),
        );
      }

      await txn.update(
        'taches',
        {
          'titre': tache.titre,
          'description': tache.description,
          'date_debut': tache.dateDebut,
          'date_fin': tache.dateFin,
          'role_requis': tache.roleRequis.index,
          if (retirerAffectation) 'utilisateur_id': null,
        },
        where: 'id = ?',
        whereArgs: [actuelle.id],
      );
    });
  }

  /// Rouvrir une tâche terminée la rend de nouveau bloquante : l'affectation
  /// est alors revérifiée, comme dans [modifierTache].
  Future<void> changerStatut(int tacheId, StatutTache statut,
      {bool retirerAffectation = false}) async {
    final utilisateurs = await _utilisateursParId();
    final db = await _database;
    await db.transaction((txn) async {
      final actuelle = await _lireTache(txn, tacheId);
      final projet = await _lireProjet(txn, actuelle.projetId);
      final acteur = _acteur();
      if (!ProjetAccess.peutChangerStatut(actuelle, projet,
          utilisateurId: acteur.utilisateurId, estAdmin: acteur.estAdmin)) {
        throw AccesRefuseException(
            'Seule la personne affectée ou le gestionnaire du projet peut changer ce statut.');
      }

      final rouverte = actuelle.statut.estTerminee && !statut.estTerminee;
      if (rouverte && actuelle.estAffectee && !retirerAffectation) {
        await _verifierAffectation(
          txn,
          tacheId: actuelle.id!,
          dateDebut: actuelle.dateDebut,
          dateFin: actuelle.dateFin,
          roleRequis: actuelle.roleRequis,
          utilisateur: _trouver(utilisateurs, actuelle.utilisateurId!),
        );
      }

      await txn.update(
        'taches',
        {
          'statut': statut.name,
          if (retirerAffectation) 'utilisateur_id': null,
        },
        where: 'id = ?',
        whereArgs: [actuelle.id],
      );
    });
  }

  Future<void> supprimerTache(int id) async {
    final db = await _database;
    await db.transaction((txn) async {
      final actuelle = await _lireTache(txn, id);
      await _exigerGestion(txn, actuelle.projetId);
      await txn.delete('taches', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ------------------------------------------------- Logique métier avancée

  /// Utilisateurs ayant exactement le rôle demandé.
  Future<List<User>> getCandidats(UserRole role) async {
    final utilisateurs = await _lireUtilisateurs();
    return utilisateurs.where((u) => u.role == role).toList();
  }

  /// Personnes ayant le rôle requis par [tache], avec leur disponibilité
  /// sur sa période. Les disponibles viennent en premier.
  Future<List<Candidat>> evaluerCandidats(Tache tache) async {
    final personnes = await getCandidats(tache.roleRequis);
    final db = await _database;
    final candidats = <Candidat>[];
    for (final u in personnes) {
      candidats.add(Candidat(
        u,
        verifierDisponibilite(
          dateDebut: tache.dateDebut,
          dateFin: tache.dateFin,
          tachesDeLaPersonne: await _tachesDe(db, u.id!),
          tacheIgnoreeId: tache.id,
          disponible: _declareDisponible(u),
        ),
      ));
    }
    return candidats
      ..sort((a, b) {
        final libreA = a.disponibilite.estDisponible;
        final libreB = b.disponibilite.estDisponible;
        if (libreA != libreB) return libreA ? -1 : 1;
        return a.utilisateur.fullName.compareTo(b.utilisateur.fullName);
      });
  }

  /// Revérifie tout dans la transaction : l'écran peut afficher des données
  /// périmées au moment où l'affectation est confirmée.
  Future<void> affecterA(Tache tache, User utilisateur) async {
    final db = await _database;
    await db.transaction((txn) async {
      final actuelle = await _lireTache(txn, tache.id!);
      await _exigerGestion(txn, actuelle.projetId);
      if (actuelle.statut.estTerminee) {
        throw ProjetException('Une tâche terminée ne peut pas être affectée.');
      }
      await _verifierAffectation(
        txn,
        tacheId: actuelle.id!,
        dateDebut: actuelle.dateDebut,
        dateFin: actuelle.dateFin,
        roleRequis: actuelle.roleRequis,
        utilisateur: utilisateur,
      );
      await txn.update('taches', {'utilisateur_id': utilisateur.id},
          where: 'id = ?', whereArgs: [actuelle.id]);
    });
  }

  // ---------------------------------------------------------------- Interne

  // TODO(Youssef Messoudi): quand le module Utilisateurs aura ajouté la
  // colonne, remplacer `true` par `utilisateur.disponible`. C'est le seul
  // endroit à changer.
  bool _declareDisponible(User utilisateur) => true;

  /// À appeler AVANT une transaction, jamais dedans : UserDao passe par la
  /// connexion principale, qui attendrait la fin de la transaction (blocage).
  Future<Map<int, User>> _utilisateursParId() async =>
      {for (final u in await _lireUtilisateurs()) u.id!: u};

  User _trouver(Map<int, User> utilisateurs, int id) =>
      utilisateurs[id] ?? (throw ProjetException('Ce compte n\'existe plus.'));

  Future<void> _verifierAffectation(
    DatabaseExecutor ex, {
    required int tacheId,
    required String dateDebut,
    required String dateFin,
    required UserRole roleRequis,
    required User utilisateur,
  }) async {
    final nom = utilisateur.fullName;
    if (utilisateur.role != roleRequis) {
      throw ConflitAffectationException(
          '$nom n\'a pas le rôle requis (${roleRequis.label}).');
    }
    final resultat = verifierDisponibilite(
      dateDebut: dateDebut,
      dateFin: dateFin,
      tachesDeLaPersonne: await _tachesDe(ex, utilisateur.id!),
      tacheIgnoreeId: tacheId,
      disponible: _declareDisponible(utilisateur),
    );
    if (resultat.estDisponible) return;
    final c = resultat.conflit;
    if (c == null) {
      throw ConflitAffectationException('$nom est indisponible.');
    }
    throw ConflitAffectationException(
      '$nom est déjà sur « ${c.titre} » (projet ${c.projetTitre}, '
      'du ${afficherDate(c.dateDebut)} au ${afficherDate(c.dateFin)}).',
      conflit: c,
    );
  }

  Future<void> _exigerGestion(DatabaseExecutor ex, int projetId) async {
    final projet = await _lireProjet(ex, projetId);
    final acteur = _acteur();
    if (!ProjetAccess.peutGererProjet(projet,
        utilisateurId: acteur.utilisateurId, estAdmin: acteur.estAdmin)) {
      throw AccesRefuseException(
          'Seuls le créateur du projet ou un administrateur peuvent faire cette action.');
    }
  }

  Future<Projet> _lireProjet(DatabaseExecutor ex, int id) async {
    final rows =
        await ex.query('projets', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw ProjetException('Ce projet n\'existe plus.');
    return Projet.fromMap(rows.first);
  }

  Future<Tache> _lireTache(DatabaseExecutor ex, int id) async {
    final rows =
        await ex.query('taches', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw ProjetException('Cette tâche n\'existe plus.');
    return Tache.fromMap(rows.first);
  }

  Future<List<Tache>> _tachesDe(DatabaseExecutor ex, int utilisateurId) async {
    final rows = await ex.rawQuery('''
      SELECT t.*, p.titre AS projet_titre
      FROM taches t JOIN projets p ON p.id = t.projet_id
      WHERE t.utilisateur_id = ?
      ORDER BY t.date_debut, t.id
    ''', [utilisateurId]);
    return rows.map(Tache.fromMap).toList();
  }

  void _verifierPeriode(String debut, String fin) {
    if (fin.compareTo(debut) < 0) {
      throw ProjetException(
          'La date de fin ne peut pas précéder la date de début.');
    }
  }
}
