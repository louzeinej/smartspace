import 'package:flutter_test/flutter_test.dart';
import 'package:smartspace/reservations/data/reservation_database.dart';
import 'package:smartspace/reservations/models/reservation.dart';
import 'package:smartspace/reservations/models/salle.dart';
import 'package:smartspace/reservations/services/reservation_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Métier avancé : créneaux alternatifs quand le créneau demandé est complet.
void main() {
  late ReservationService service;
  late int a1, b2;

  Reservation resa(int salle, String debut, String fin) => Reservation(
      salleId: salle, utilisateurId: 1, objet: 'r', date: '2030-01-01',
      heureDebut: debut, heureFin: fin, nbPersonnes: 2);

  setUp(() async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          singleInstance: false,
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, _) => ReservationDatabase.createTables(db),
        ));
    service = ReservationService(database: Future.value(db));
    a1 = await service.ajouterSalle(
        const Salle(numero: 'A1', emplacement: 'Bloc A', capacite: 4));
    b2 = await service.ajouterSalle(
        const Salle(numero: 'B2', emplacement: 'Bloc B', capacite: 10));
  });

  Future<List<CreneauAlternatif>> proposer(String debut, String fin,
          {int nb = 2, String? maintenant}) =>
      service.proposerCreneauxAlternatifs(
          date: '2030-01-01', heureDebut: debut, heureFin: fin,
          nbPersonnes: nb, maintenant: maintenant);

  test('propose les créneaux les plus proches, même durée, plus petite salle',
      () async {
    // 10:00–11:00 complet dans les deux salles.
    await service.reserver(resa(a1, '10:00', '11:00'));
    await service.reserver(resa(b2, '10:00', '11:00'));

    final p = await proposer('10:00', '11:00');
    // 09:00 et 11:00 sont à égalité (écart 60 min) : le plus tôt d'abord.
    expect(p[0].heureDebut, '09:00');
    expect(p[1].heureDebut, '11:00');
    expect(p[1].heureFin, '12:00'); // même durée (1 h)
    expect(p[0].salle.numero, 'A1'); // la plus petite salle suffisante
    expect(p.length, 5);
    // Aucun créneau proposé ne chevauche 10:00–11:00.
    for (final c in p) {
      expect(c.heureDebut.compareTo('11:00') >= 0 || c.heureFin.compareTo('10:00') <= 0,
          isTrue);
    }
  });

  test('saute la petite salle occupée et prend la suivante', () async {
    await service.reserver(resa(a1, '10:00', '12:00'));
    await service.reserver(resa(b2, '10:00', '11:00'));

    final p = await proposer('10:00', '11:00');
    // 11:00–12:00 : A1 occupée, B2 libre.
    final onze = p.firstWhere((c) => c.heureDebut == '11:00');
    expect(onze.salle.numero, 'B2');
  });

  test('respecte capacité, horaires d\'ouverture et heure actuelle', () async {
    // 6 personnes : seule B2 convient.
    final p = await proposer('18:00', '19:00', nb: 6, maintenant: '17:10');
    expect(p.every((c) => c.salle.numero == 'B2'), isTrue);
    expect(p.every((c) => c.heureFin.compareTo('19:00') <= 0), isTrue);
    expect(p.every((c) => c.heureDebut.compareTo('17:10') >= 0), isTrue);
    // Personne au-dessus de la capacité max : aucune proposition.
    expect(await proposer('10:00', '11:00', nb: 50), isEmpty);
  });
}
