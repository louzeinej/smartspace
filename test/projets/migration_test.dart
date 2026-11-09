import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:smartspace/core/database_helper.dart';
import 'package:smartspace/database/user_database.dart';
import 'package:smartspace/reservations/data/reservation_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Migre une vraie base v4 avec le vrai `DatabaseHelper`, dans un dossier
/// temporaire pour ne jamais toucher à la base de développement.
void main() {
  test('v4 → version courante : ajoute mes tables, garde celles des autres',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dossier = await Directory.systemTemp.createTemp('smartspace_test');
    addTearDown(() => dossier.delete(recursive: true));
    await databaseFactory.setDatabasesPath(dossier.path);

    final v4 = await databaseFactory.openDatabase(
      join(dossier.path, 'smartspace.db'),
      options: OpenDatabaseOptions(
        version: 4,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: (d, _) async {
          await UserDatabase.createTables(d);
          await UserDatabase.seedDemoUsers(d);
          await ReservationDatabase.createTables(d);
        },
      ),
    );
    final salle = await v4.insert(
        'salles', {'numero': 'Z9', 'emplacement': 'Test', 'capacite': 2});
    await v4.insert('reservations', {
      'salle_id': salle,
      'utilisateur_id': 1,
      'objet': 'Réunion',
      'date': '2026-03-01',
      'heure_debut': '08:00',
      'heure_fin': '09:00',
      'nb_personnes': 2,
    });
    await v4.close();

    final db = await DatabaseHelper.instance.database;
    addTearDown(db.close);

    expect(await db.getVersion(), greaterThan(4));

    final tables = (await db
            .rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
        .map((r) => r['name']);
    expect(tables, containsAll(['projets', 'taches']));

    final fk = await db.rawQuery('PRAGMA foreign_keys');
    expect(fk.first.values.first, 1);

    // Données des autres modules intactes, et pas de nouveau seed.
    expect((await db.query('users')).length, 5);
    expect((await db.query('salles')).map((r) => r['numero']), ['Z9']);
    expect((await db.query('reservations')).single['objet'], 'Réunion');
  });
}
