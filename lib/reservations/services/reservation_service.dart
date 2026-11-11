import 'package:sqflite/sqflite.dart';

import '../../core/database_helper.dart';
import '../models/reservation.dart';
import '../models/salle.dart';

/// Résultat de recherche : la salle, et le créneau qui la bloque s'il y en a un.
class SalleResultat {
  final Salle salle;
  final String? conflit;
  SalleResultat(this.salle, this.conflit);
  bool get disponible => conflit == null;
}

/// Proposition de remplacement quand aucune salle n'est libre :
/// une salle et un créneau de même durée, le même jour.
class CreneauAlternatif {
  final Salle salle;
  final String heureDebut;
  final String heureFin;
  CreneauAlternatif(this.salle, this.heureDebut, this.heureFin);
}

class ReservationException implements Exception {
  final String message;
  ReservationException(this.message);
  @override
  String toString() => message;
}

/// CRUD des salles et des réservations + logique métier :
/// recherche des salles disponibles selon date, créneau et capacité.
class ReservationService {
  ReservationService({Future<Database>? database})
      : _database = database ?? DatabaseHelper.instance.database;

  final Future<Database> _database;

  // ---------------------------------------------------------------- Salles

  Future<List<Salle>> getSalles() async {
    final db = await _database;
    final rows = await db.query('salles', orderBy: 'numero');
    return rows.map(Salle.fromMap).toList();
  }

  Future<int> ajouterSalle(Salle salle) async {
    final db = await _database;
    try {
      return await db.insert('salles', salle.toMap());
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw ReservationException('La salle n°${salle.numero} existe déjà.');
      }
      rethrow;
    }
  }

  Future<void> modifierSalle(Salle salle) async {
    final db = await _database;
    try {
      await db.update('salles', salle.toMap(),
          where: 'id = ?', whereArgs: [salle.id]);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw ReservationException('La salle n°${salle.numero} existe déjà.');
      }
      rethrow;
    }
  }

  /// Supprime la salle et ses réservations (ON DELETE CASCADE).
  Future<void> supprimerSalle(int id) async {
    final db = await _database;
    await db.delete('salles', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------- Logique métier avancée

  /// Salles libres sur le créneau [heureDebut]–[heureFin] du [date]
  /// et dont la capacité couvre [nbPersonnes].
  ///
  /// Triées par capacité croissante : la première est la plus adaptée
  /// (une petite réunion se voit proposer une petite salle).
  /// [ignorerReservationId] sert lors de la modification d'une réservation.
  Future<List<Salle>> rechercherSallesDisponibles({
    required String date,
    required String heureDebut,
    required String heureFin,
    required int nbPersonnes,
    int? ignorerReservationId,
  }) async {
    _verifierCreneau(heureDebut, heureFin);
    final db = await _database;
    // Deux créneaux se chevauchent si debutA < finB ET finA > debutB.
    final rows = await db.rawQuery('''
      SELECT s.* FROM salles s
      WHERE s.capacite >= ?
        AND NOT EXISTS (
          SELECT 1 FROM reservations r
          WHERE r.salle_id = s.id
            AND r.date = ?
            AND r.heure_debut < ?
            AND r.heure_fin > ?
            AND r.id != ?
        )
      ORDER BY s.capacite ASC, s.numero ASC
    ''', [nbPersonnes, date, heureFin, heureDebut, ignorerReservationId ?? -1]);
    return rows.map(Salle.fromMap).toList();
  }

  /// Comme [rechercherSallesDisponibles], mais renvoie aussi les salles
  /// assez grandes déjà réservées sur ce créneau, marquées non disponibles,
  /// avec le créneau qui les bloque. Les disponibles viennent en premier.
  Future<List<SalleResultat>> rechercherSalles({
    required String date,
    required String heureDebut,
    required String heureFin,
    required int nbPersonnes,
  }) async {
    _verifierCreneau(heureDebut, heureFin);
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT s.*,
        (SELECT r.heure_debut || '–' || r.heure_fin || ' · ' || r.objet
           FROM reservations r
          WHERE r.salle_id = s.id AND r.date = ?
            AND r.heure_debut < ? AND r.heure_fin > ?
          ORDER BY r.heure_debut LIMIT 1) AS conflit
      FROM salles s
      WHERE s.capacite >= ?
    ''', [date, heureFin, heureDebut, nbPersonnes]);
    final res = rows
        .map((m) => SalleResultat(Salle.fromMap(m), m['conflit'] as String?))
        .toList()
      ..sort((a, b) {
        if (a.disponible != b.disponible) return a.disponible ? -1 : 1;
        return a.salle.capacite.compareTo(b.salle.capacite);
      });
    return res;
  }

  // ------------------------------------- Métier avancé : créneaux alternatifs

  /// Heures d'ouverture des locaux et pas de recherche (minutes).
  static const ouverture = '08:00';
  static const fermeture = '19:00';
  static const pasMinutes = 30;

  /// Quand le créneau demandé est complet, propose jusqu'à [max] créneaux
  /// libres de MÊME DURÉE, le MÊME JOUR, entre [ouverture] et [fermeture],
  /// classés du plus proche au plus éloigné de l'heure demandée.
  ///
  /// Algorithme :
  /// 1. 2 requêtes SQL : salles assez grandes + réservations du jour.
  /// 2. On teste chaque heure de début possible (pas de 30 min).
  /// 3. Pour chaque début, on garde la plus petite salle sans chevauchement
  ///    (même règle : debutA < finB ET finA > debutB).
  /// 4. Tri par écart avec l'heure demandée, puis par heure.
  ///
  /// [maintenant] (HH:mm) exclut les créneaux déjà passés si [date] est
  /// aujourd'hui.
  Future<List<CreneauAlternatif>> proposerCreneauxAlternatifs({
    required String date,
    required String heureDebut,
    required String heureFin,
    required int nbPersonnes,
    String? maintenant,
    int max = 5,
  }) async {
    _verifierCreneau(heureDebut, heureFin);
    final db = await _database;

    // 1. Données nécessaires, lues une seule fois.
    final salles = (await db.query('salles',
            where: 'capacite >= ?',
            whereArgs: [nbPersonnes],
            orderBy: 'capacite ASC, numero ASC'))
        .map(Salle.fromMap)
        .toList();
    if (salles.isEmpty) return [];
    final occupations = await db.query('reservations',
        columns: ['salle_id', 'heure_debut', 'heure_fin'],
        where: 'date = ?',
        whereArgs: [date]);

    final debutDemande = _enMinutes(heureDebut);
    final duree = _enMinutes(heureFin) - debutDemande;
    final premier = _enMinutes(ouverture);
    final dernier = _enMinutes(fermeture) - duree;
    final limitePassee = maintenant == null ? -1 : _enMinutes(maintenant);

    // 2-3. Chaque début possible -> plus petite salle libre.
    final propositions = <CreneauAlternatif>[];
    for (var debut = premier; debut <= dernier; debut += pasMinutes) {
      if (debut == debutDemande || debut < limitePassee) continue;
      final hDebut = _enHeure(debut);
      final hFin = _enHeure(debut + duree);
      for (final salle in salles) {
        final occupee = occupations.any((o) =>
            o['salle_id'] == salle.id &&
            (o['heure_debut'] as String).compareTo(hFin) < 0 &&
            (o['heure_fin'] as String).compareTo(hDebut) > 0);
        if (!occupee) {
          propositions.add(CreneauAlternatif(salle, hDebut, hFin));
          break; // la plus petite salle suffit pour ce créneau
        }
      }
    }

    // 4. Les plus proches de l'heure demandée d'abord.
    propositions.sort((a, b) {
      final ea = (_enMinutes(a.heureDebut) - debutDemande).abs();
      final eb = (_enMinutes(b.heureDebut) - debutDemande).abs();
      return ea != eb ? ea.compareTo(eb) : a.heureDebut.compareTo(b.heureDebut);
    });
    return propositions.take(max).toList();
  }

  static int _enMinutes(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  static String _enHeure(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  /// Réservations à venir (aujourd'hui inclus) de toutes les salles,
  /// regroupées par id de salle.
  Future<Map<int, List<Reservation>>> getReservationsAVenirParSalle(
      String aPartirDe) async {
    final db = await _database;
    final rows = await db.query('reservations',
        where: 'date >= ?', whereArgs: [aPartirDe], orderBy: 'date, heure_debut');
    final map = <int, List<Reservation>>{};
    for (final r in rows.map(Reservation.fromMap)) {
      map.putIfAbsent(r.salleId, () => []).add(r);
    }
    return map;
  }

  // ----------------------------------------------------------- Réservations

  Future<List<Reservation>> getReservationsUtilisateur(int utilisateurId) async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT r.*, s.numero AS salle_numero, s.emplacement AS salle_emplacement
      FROM reservations r JOIN salles s ON s.id = r.salle_id
      WHERE r.utilisateur_id = ?
      ORDER BY r.date, r.heure_debut
    ''', [utilisateurId]);
    return rows.map(Reservation.fromMap).toList();
  }

  /// Revérifie la disponibilité juste avant l'insertion, pour ne jamais
  /// enregistrer deux réservations qui se chevauchent sur la même salle.
  Future<int> reserver(Reservation r) async {
    final db = await _database;
    return db.transaction((txn) async {
      if (!await _estDisponible(txn, r)) {
        throw ReservationException(
            'Cette salle vient d\'être réservée sur ce créneau ou est trop petite.');
      }
      return txn.insert('reservations', r.toMap());
    });
  }

  Future<void> modifierReservation(Reservation r) async {
    final db = await _database;
    await db.transaction((txn) async {
      if (!await _estDisponible(txn, r)) {
        throw ReservationException(
            'La salle n\'est pas disponible sur ce créneau ou est trop petite.');
      }
      await txn.update('reservations', r.toMap(),
          where: 'id = ?', whereArgs: [r.id]);
    });
  }

  Future<void> annulerReservation(int id) async {
    final db = await _database;
    await db.delete('reservations', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------- Interne

  Future<bool> _estDisponible(DatabaseExecutor ex, Reservation r) async {
    _verifierCreneau(r.heureDebut, r.heureFin);
    final rows = await ex.rawQuery('''
      SELECT 1 FROM salles s
      WHERE s.id = ? AND s.capacite >= ?
        AND NOT EXISTS (
          SELECT 1 FROM reservations x
          WHERE x.salle_id = s.id AND x.date = ?
            AND x.heure_debut < ? AND x.heure_fin > ?
            AND x.id != ?
        )
    ''', [r.salleId, r.nbPersonnes, r.date, r.heureFin, r.heureDebut, r.id ?? -1]);
    return rows.isNotEmpty;
  }

  void _verifierCreneau(String debut, String fin) {
    if (debut.compareTo(fin) >= 0) {
      throw ReservationException(
          'L\'heure de fin doit être après l\'heure de début.');
    }
  }
}
