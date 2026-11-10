import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Tables que la base partagée doit contenir, tous modules confondus.
const tablesAttendues = [
  'users', // Utilisateurs
  'projets', 'taches', // Projets et Tâches
  'salles', 'reservations', 'jours_feries', // Réservations
  'publications', 'publication_likes', 'publication_comments', // Networking
  'poll_options', 'poll_votes', 'training_enrollments',
];

Future<List<String>> tablesDe(Database db) async => (await db
        .rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
    .map((r) => r['name'] as String)
    .toList();
