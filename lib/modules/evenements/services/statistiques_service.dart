import 'database_service.dart';

// Statistiques de participation (pour l'administrateur).
// Un "participant" = une PERSONNE inscrite : on additionne nombre_personnes.
// Tous les calculs sont faits directement en SQL.
class StatistiquesService {
  final DatabaseService _dbService = DatabaseService.instance;

  // Lit un seul nombre dans le résultat d'une requête (0 si vide)
  Future<int> _unNombre(String sql) async {
    final db = await _dbService.database;
    final lignes = await db.rawQuery(sql);
    return (lignes.first['valeur'] as int?) ?? 0;
  }

  // Les grands chiffres du tableau de bord
  Future<Map<String, int>> chiffresCles() async {
    return {
      // Total de personnes inscrites
      'participants': await _unNombre(
        'SELECT COALESCE(SUM(nombre_personnes), 0) AS valeur '
        'FROM participations',
      ),
      // Nombre d'employés différents qui participent
      'employes': await _unNombre(
        'SELECT COUNT(DISTINCT utilisateur_id) AS valeur FROM participations',
      ),
      'activites': await _unNombre(
        'SELECT COUNT(*) AS valeur FROM activites',
      ),
      'evenements': await _unNombre(
        'SELECT COUNT(*) AS valeur FROM evenements',
      ),
      // Nombre total de places proposées
      'capaciteTotale': await _unNombre(
        'SELECT COALESCE(SUM(capacite_max), 0) AS valeur FROM activites',
      ),
      // Activités où le nombre de personnes inscrites atteint la capacité
      'activitesCompletes': await _unNombre('''
        SELECT COUNT(*) AS valeur FROM (
          SELECT a.id
          FROM activites a
          LEFT JOIN participations p ON p.activite_id = a.id
          GROUP BY a.id
          HAVING COALESCE(SUM(p.nombre_personnes), 0) >= a.capacite_max
        )
      '''),
    };
  }

  // Participants par catégorie, de la plus populaire à la moins populaire
  Future<List<Map<String, Object?>>> parCategorie() async {
    final db = await _dbService.database;
    return await db.rawQuery('''
      SELECT a.categorie AS categorie,
             COALESCE(SUM(p.nombre_personnes), 0) AS total
      FROM activites a
      LEFT JOIN participations p ON p.activite_id = a.id
      GROUP BY a.categorie
      ORDER BY total DESC
    ''');
  }

  // Les activités qui ont le plus de participants
  Future<List<Map<String, Object?>>> topActivites({int limite = 5}) async {
    final db = await _dbService.database;
    return await db.rawQuery('''
      SELECT a.titre AS titre,
             a.categorie AS categorie,
             e.titre AS evenement,
             a.capacite_max AS capacite_max,
             COALESCE(SUM(p.nombre_personnes), 0) AS total
      FROM activites a
      JOIN evenements e ON e.id = a.evenement_id
      LEFT JOIN participations p ON p.activite_id = a.id
      GROUP BY a.id
      ORDER BY total DESC
      LIMIT ?
    ''', [limite]);
  }
}
