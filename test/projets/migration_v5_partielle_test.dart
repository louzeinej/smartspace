import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:smartspace/core/database_helper.dart';
import 'package:smartspace/database/user_database.dart';
import 'package:smartspace/projets/data/projet_database.dart';
import 'package:smartspace/reservations/data/reservation_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'tables_attendues.dart';

/// La v5 a été attribuée en parallèle par plusieurs modules : un appareil
/// passé en v5 avec la branche Projets seule n'a ni `jours_feries` ni les
/// tables Networking. La version suivante doit les créer sans rien perdre.
void main() {
  test('v5 partielle (Projets seul) → version courante : tables complétées',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dossier = await Directory.systemTemp.createTemp('smartspace_test');
    addTearDown(() => dossier.delete(recursive: true));
    await databaseFactory.setDatabasesPath(dossier.path);

    final v5 = await databaseFactory.openDatabase(
      join(dossier.path, 'smartspace.db'),
      options: OpenDatabaseOptions(
        version: 5,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: (d, _) async {
          await UserDatabase.createTables(d);
          await UserDatabase.seedDemoUsers(d);
          await ProjetDatabase.createTables(d);
          await ReservationDatabase.createTables(d);
          await d.execute('DROP TABLE jours_feries'); // pas sur cette branche
        },
      ),
    );
    final projet = await v5.insert('projets', {
      'titre': 'test 1',
      'description': 'D',
      'date_creation': '2026-11-09',
      'createur_id': 2,
    });
    await v5.insert('taches', {
      'titre': 'Maquette',
      'description': 'D',
      'date_debut': '2026-11-10',
      'date_fin': '2026-11-12',
      'role_requis': 1,
      'statut': 'aFaire',
      'projet_id': projet,
      'utilisateur_id': 4,
    });
    await v5.close();

    final db = await DatabaseHelper.instance.database;
    addTearDown(db.close);

    expect(await db.getVersion(), greaterThan(5));
    expect(await tablesDe(db), containsAll(tablesAttendues));
    expect((await db.query('taches')).single['utilisateur_id'], 4);
    expect((await db.query('projets')).single['titre'], 'test 1');
    expect((await db.query('users')).length, 5);
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });
}
