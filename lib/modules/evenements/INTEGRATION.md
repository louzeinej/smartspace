# Module Événements et Club — guide d'intégration

Ce guide explique comment brancher le module **Événements** dans le projet commun SmartSpace.

## 1. Ce que fait le module

- **Événements** : créer, modifier, supprimer (avec confirmation), avec une photo de couverture.
- **Activités** : chaque événement a des activités (horaires, catégorie, capacité maximale, minimum de participants facultatif).
- **Participations** : un employé s'inscrit à une activité pour 1 à 5 personnes (lui + ses invités), peut modifier ce nombre ou annuler.
- **Règles métier** (voir la section 7) : capacité, double inscription, conflit d'horaires, statut automatique, limite par inscription, minimum de participants.
- **Mes inscriptions** : liste des activités de l'employé, onglets « À venir » et « Passées ».
- **Statistiques** : chiffres clés, catégories et activités les plus populaires (calculs en SQL).
- **Météo** : sur le détail d'un événement, la météo prévue vient de l'API gratuite **Open-Meteo** (sans clé). Elle n'est disponible que pour les 15 prochains jours, sinon un message « Météo indisponible » s'affiche.

## 2. Fichiers à copier dans le projet commun

- `lib/modules/evenements/` (tout le dossier)
- `assets/images/evenements/` (les photos de couverture : `fete.jpg`, `formation.jpg`, `tournoi_sportif.jpg`)

La liste des photos proposées dans le formulaire est dans `entities/images_evenements.dart`.

## 3. Dépendances et configuration

Dans `pubspec.yaml`, section `dependencies` (versions utilisées dans le module) :

```yaml
  sqflite: ^2.4.4+1
  path: ^1.9.1
  image_picker: ^1.2.4        # choix d'une photo dans le formulaire d'événement
  path_provider: ^2.1.6       # dossier où la photo choisie est copiée
  shared_preferences: ^2.5.6  # mémorise l'employé simulé (UtilisateurCourant)
  http: ^1.6.0                # météo Open-Meteo
```

Si le projet commun a déjà certains de ces paquets (par exemple `sqflite`, `path` ou `shared_preferences`), gardez la version la plus récente des deux.
`shared_preferences` ne sert qu'à la simulation de connexion : il pourra être retiré avec `UtilisateurCourant` (section 6).

Dans la section `flutter:` du même fichier, déclarer les photos :

```yaml
  assets:
    - assets/images/evenements/
```

Dans `android/app/src/main/AndroidManifest.xml`, avant la balise `<application>` :

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

(nécessaire pour la météo dans l'application installée).

## 4. Point d'entrée

`EvenementListScreen` (`lib/modules/evenements/screens/evenement_list_screen.dart`) est l'écran d'accueil du module.
Il a son propre `Scaffold` et sa barre violette : il se place directement dans l'onglet **Événements** de la barre de navigation.

Les autres écrans sont ouverts depuis celui-ci (détail, formulaires, statistiques, mes inscriptions).

## 5. Base de données

- Fichier **séparé** : `smartspace_evenements.db`, version **5**, géré par `services/database_service.dart` (`DatabaseService.instance.database`).
- Tables :
  - `evenements` (id, titre, description, date, lieu, image)
  - `activites` (id, evenement_id, titre, description, heure_debut, heure_fin, capacite_max, capacite_min, categorie)
  - `participations` (id, activite_id, utilisateur_id, date_inscription, nombre_personnes ; unique sur activite_id + utilisateur_id)
- Les clés étrangères sont activées (`PRAGMA foreign_keys = ON`) : supprimer un événement supprime ses activités, et supprimer une activité supprime ses participations.
- `utilisateur_id` n'a pas de clé étrangère : il contient l'id de l'utilisateur connecté.

**Pour fusionner dans la base commune** (une seule base pour tous les modules) :

1. Dans `DatabaseService`, déplacer les trois `CREATE TABLE` de `_createDB` dans une fonction `createTables(db)` (avec `CREATE TABLE IF NOT EXISTS`), sur le modèle des autres modules.
2. L'appeler depuis le `_onCreate` du `DatabaseHelper` commun, et augmenter sa version.
3. Dans les services (`evenement_service`, `activite_service`, `participation_service`, `statistiques_service`, `donnees_demo_service`), remplacer `DatabaseService.instance.database` par la base commune.
4. Dans le `CREATE TABLE` définitif, les colonnes `image`, `capacite_min` et `nombre_personnes` doivent déjà être présentes (les `ALTER TABLE` de `_upgradeDB` ne servent qu'aux anciennes versions de la base séparée).
5. Les données d'exemple d'`onCreate` (`_insererExemples`) sont à retirer ou à mettre ailleurs.

## 6. À remplacer à l'intégration

- **Utilisateur connecté** : `UtilisateurCourant.id` (dans `entities/utilisateur_courant.dart`) est une simulation. Le remplacer partout par l'id de l'utilisateur connecté du module Utilisateurs (par exemple `Session.utilisateurId`), puis supprimer `UtilisateurCourant` et son appel `UtilisateurCourant.charger()` dans `main.dart`.
  Le nom affiché (`UtilisateurCourant.nom()`) se remplace de la même façon.
- **Droits** : aujourd'hui tout le monde peut tout faire. À faire :
  - réserver la gestion (créer, modifier, supprimer des événements et des activités) aux rôles **Administrateur** et **RH** (par exemple avec `ModuleAccess.canManageActivities`) ;
  - laisser la participation (s'inscrire, modifier, annuler) à **tous** les utilisateurs connectés ;
  - restreindre l'écran des statistiques à l'Administrateur.
- **Outils de simulation** : retirer de la barre violette de `evenement_list_screen.dart` les icônes visibles en mode debug (données de démo, inscrire l'employé courant, simuler une connexion), avec leurs méthodes.
- **Données de démo** : mettre `kCreerDonneesDemo` à `false` dans `services/donnees_demo_service.dart`. Sinon, en mode debug, l'événement « Journée Clubs & Ateliers » est créé automatiquement au démarrage de la liste (appel dans `_demarrer`, marqué « À SUPPRIMER avant l'intégration »).

## 7. Règles métier et où elles sont

| Règle | Fichier |
|---|---|
| Pas d'inscription à une activité terminée ou déjà commencée | `services/participation_service.dart` (`inscrire`) |
| Pas de double inscription (aussi garantie par `UNIQUE` en base) | `participation_service.dart` (`inscrire`) |
| Conflit d'horaires : pas deux activités qui se chevauchent le même jour (deux créneaux qui se touchent, comme 08:00-10:00 et 10:00-12:00, ne sont pas un conflit) | `participation_service.dart` (`trouverConflitHoraire`, `chevauche`) |
| Capacité : pas de nouvelle inscription si l'activité est complète, pas plus de personnes que de places restantes | `participation_service.dart` (`inscrire`, `modifierNombrePersonnes`) |
| Limite de 5 personnes par inscription (valeur dans une seule constante) | `entities/regles_participation.dart` (`maxPersonnesParInscription`), contrôlée dans `participation_service.dart` |
| Statut automatique : ouverte, presque complète (80 %), complète, en cours, terminée, annulée | `entities/statut_activite.dart` (`calculerStatut`) |
| Minimum de participants : une activité qui commence sans atteindre son minimum est annulée | `statut_activite.dart` et `participation_service.dart` (`inscrire`) |
| La capacité ne peut pas être inférieure au nombre d'inscrits ; le minimum ne dépasse pas la capacité maximale | `services/activite_service.dart` (`modifier`, `ajouter`) |
| Annuler sa participation reste toujours possible | `participation_service.dart` (`desinscrire`) |

Un « participant » est une **personne** inscrite : on additionne `nombre_personnes`, on ne compte pas les lignes.
Les contrôles de formulaire (date `AAAA-MM-JJ` valide, heures `HH:MM`, champs obligatoires) sont dans les écrans `evenement_form_screen.dart` et `activite_form_screen.dart`.

Statistiques : `services/statistiques_service.dart`. Météo : `services/meteo_service.dart`.
