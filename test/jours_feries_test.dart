import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartspace/reservations/data/reservation_database.dart';
import 'package:smartspace/reservations/models/reservation.dart';
import 'package:smartspace/reservations/models/salle.dart';
import 'package:smartspace/reservations/services/jours_feries_service.dart';
import 'package:smartspace/reservations/services/reservation_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> baseEnMemoire() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        singleInstance: false, // une base neuve par test
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => ReservationDatabase.createTables(db),
      ));
  return db;
}

void main() {
  test('API jours fériés : appel, traduction, puis cache hors ligne', () async {
    final db = await baseEnMemoire();
    var appels = 0;
    final client = MockClient((req) async {
      appels++;
      expect(req.url.toString(),
          'https://date.nager.at/api/v3/PublicHolidays/2026/TN');
      return http.Response(
          '[{"date":"2026-03-20","name":"Independence Day"}]', 200);
    });
    final service = JoursFeriesService(database: Future.value(db), client: client);

    expect(await service.jourFerie('2026-03-20'), "Fête de l'Indépendance");
    expect(await service.jourFerie('2026-03-21'), isNull);
    expect(appels, 1, reason: 'la 2e lecture vient du cache SQLite');
  });

  test('API jours fériés : sans internet, pas d\'erreur', () async {
    final db = await baseEnMemoire();
    final client = MockClient((_) async => throw Exception('hors ligne'));
    final service = JoursFeriesService(database: Future.value(db), client: client);
    expect(await service.jourFerie('2026-03-20'), isNull);
  });

  test('Modifier une réservation : refus si chevauchement', () async {
    final db = await baseEnMemoire();
    final service = ReservationService(database: Future.value(db));
    final salle = await service.ajouterSalle(
        const Salle(numero: 'T1', emplacement: 'Test', capacite: 10));
    Reservation resa(String debut, String fin, {int? id}) => Reservation(
        id: id, salleId: salle, utilisateurId: 1, objet: 'r',
        date: '2030-01-01', heureDebut: debut, heureFin: fin, nbPersonnes: 2);

    final a = await service.reserver(resa('09:00', '10:00'));
    await service.reserver(resa('11:00', '12:00'));

    // Décaler A dans un créneau libre : accepté (A ne se bloque pas elle-même).
    await service.modifierReservation(resa('09:30', '10:30', id: a));
    // Décaler A sur B : refusé.
    expect(() => service.modifierReservation(resa('10:30', '11:30', id: a)),
        throwsA(isA<ReservationException>()));
  });
}
