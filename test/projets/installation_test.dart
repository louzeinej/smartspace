import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartspace/core/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'tables_attendues.dart';

/// Première installation : toutes les tables de tous les modules existent.
void main() {
  test('installation neuve : tables de tous les modules et données de démo',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dossier = await Directory.systemTemp.createTemp('smartspace_test');
    addTearDown(() => dossier.delete(recursive: true));
    await databaseFactory.setDatabasesPath(dossier.path);

    final db = await DatabaseHelper.instance.database;
    addTearDown(db.close);

    expect(await db.getVersion(), greaterThan(5));
    expect(await tablesDe(db), containsAll(tablesAttendues));
    expect((await db.query('users')).length, 5);
    expect((await db.query('salles')).length, 3);
    expect(await db.query('publications'), isNotEmpty);
    expect(await db.query('projets'), isEmpty);
  });
}
