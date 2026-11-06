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
