# SmartSpace 🏢

Application mobile de **gestion interne d'entreprise** développée en **Flutter** avec base de données locale **SQLite** (sqflite). Architecture **offline-first** : aucune donnée ne transite par un serveur distant, l'application fonctionne intégralement sans connexion.

> Projet de développement mobile — 5 modules, 5 membres d'équipe, un seul produit.

---

## 📱 Les modules

L'application est organisée en **5 modules** accessibles depuis une barre de navigation basse (une icône par module) :

| Onglet | Module | Responsable | Statut |
|---|---|---|---|
| 👤 Utilisateurs | Comptes, rôles, authentification | **Youssef Messoudi** | ✅ Intégré |
| ✅ Projets | Projets, tâches, vérification de disponibilité | Youssef Sghaier | 🚧 À venir |
| 🚪 Salles | Salles, réservations (création, modification, annulation), recherche par critères, alerte jours fériés | **Youssef Fadaoui** | ✅ Intégré |
| 💬 Réseau | Publications, actualités internes | Manar Kalai | 🚧 À venir |
| 🎉 Événements | Activités de club, participations, capacité | Louzeine Aloui | 🚧 À venir |

---

## 🔑 Comptes de démonstration

Créés automatiquement au **premier lancement** (installation fraîche) :

| Membre | Email | Mot de passe | Rôle |
|---|---|---|---|
| **Youssef Messoudi** 👑 | `admin@smartspace.tn` | `Admin123` | **Administrateur** |
| Youssef Sghaier | `scrum@smartspace.tn` | `Scrum123` | Scrum Master |
| Youssef Fadaoui | `fadaoui@smartspace.tn` | `Fadaoui1` | Employé * |
| Manar Kalai | `uiux@smartspace.tn` | `Uiux1234` | UI/UX Designer |
| Louzeine Aloui | `louzeine@smartspace.tn` | `Louz1234` | RH |

\* Démo du contrôle d'accès : Fadaoui démarre Employé — l'Administrateur le **promeut en direct** depuis l'écran *Gestion des rôles* pour lui donner accès à la gestion des salles.

**Question secrète commune aux comptes de démo** : « Quel est le nom de votre équipe ? » → réponse : `smartspace`
**Téléphone admin** (reset par SMS simulé) : `20111223`

---

## ✨ Module Gestion des Utilisateurs (fonctionnalités)

- **Authentification** : inscription, connexion, déconnexion ; mots de passe **hachés SHA-256** (jamais en clair en base) ; session persistée (SharedPreferences) et restaurée au démarrage
- **Mot de passe oublié — 3 méthodes** :
  1. **Code par email** : code à 6 chiffres généré par le web service [random.org](https://www.random.org), envoyé **par vrai email** via Gmail SMTP ou l'API Brevo (config. dans `lib/services/email_otp_service.dart`), valable 10 minutes. Sans configuration → email simulé (démo)
  2. **Par numéro de téléphone** : le code fonctionne aussi avec le téléphone du compte (résolution email/téléphone automatique)
  3. **Question secrète** (100 % offline) : réponse hachée SHA-256
- **Annuaire** : liste, recherche nom/email (SQL), filtre par rôle
- **Profils** : avatar généré par l'API [DiceBear](https://www.dicebear.com), badge de rôle, édition (nom, email, téléphone), changement de mot de passe
- **Gestion des rôles** (Administrateur) : matrice des permissions par rôle, promotion/rétrogradation en un geste, création de comptes
- **Assistant intelligent intégré** 🤖 : chat qui interroge la base locale (recherche de membres, statistiques par rôle, aide)
- **Contrôle d'accès** : `core/module_access.dart` = source unique des règles, consommée par tous les modules via `Session.roleEnum`

## 🚪 Module Gestion des Réservations de Salles (fonctionnalités)

- **Recherche intelligente** : date, créneau et nombre de participants → seules les salles **libres et assez grandes** sont proposées, de la plus petite à la plus grande ; les salles occupées sont affichées à part avec le créneau qui les bloque
- **Règle de chevauchement** (SQL `NOT EXISTS`) : deux créneaux se chevauchent si `début existant < fin demandée` et `fin existante > début demandé` (9h–10h puis 10h–11h est autorisé)
- **Réservation sécurisée** : disponibilité revérifiée dans une **transaction** juste avant l'enregistrement → jamais deux réservations en conflit
- **Mes réservations** : liste avec **modification** (objet, participants, salle, date, créneau — revérifiée en transaction) et **annulation** avec confirmation
- **Gestion des salles** (Administrateur) : ajout, modification, suppression (numéro unique, capacité > 0)
- **Alerte jour férié** 🎉 : à la sélection d'une date, bandeau si le jour est férié en Tunisie (API Nager.Date, voir *Web services*)
- **SQLite** : tables `salles`, `reservations` (clé étrangère `ON DELETE CASCADE`, contraintes `CHECK`, index `(salle_id, date)`), `jours_feries` (cache de l'API) — base v5
- **Tests** : `test/jours_feries_test.dart` (API simulée + cache, mode hors ligne, refus de chevauchement)

### Règles de rôles (ModuleAccess)

| Permission | Admin | Scrum Master | RH | Autres |
|---|:-:|:-:|:-:|:-:|
| Gérer comptes & rôles | ✅ | | | |
| Créer projets / affecter tâches | ✅ | ✅ | | |
| Référencer des salles | ✅ | | | |
| Réserver une salle / publier / s'inscrire à une activité | ✅ | ✅ | ✅ | ✅ |
| Organiser des événements & clubs | ✅ | | ✅ | |

---

## 🏗️ Architecture

```
lib/
├── main.dart                        # Point d'entrée (Provider + thème)
├── core/
│   ├── database_helper.dart         # Base SQLite unique (v4) partagée par les 5 modules
│   ├── session.dart                 # Utilisateur connecté (id, nom, rôle) — partagé
│   ├── module_access.dart           # Règles de rôles centralisées
│   └── home_shell.dart              # Barre de navigation 5 onglets
├── models/                          # User, UserRole (enum)
├── database/                        # user_database (schéma + seed), user_dao (SQL)
├── services/
│   ├── auth_service.dart            # Inscription/login/reset — hachage SHA-256
│   ├── avatar_service.dart          # API DiceBear (avatars)
│   ├── verification_code_service.dart # random.org (codes OTP)
│   └── email_otp_service.dart       # Gmail SMTP / Brevo (envoi réel des OTP)
├── providers/auth_provider.dart     # État de session réactif (ChangeNotifier)
├── screens/                         # splash, login, register, annuaire, profil,
│                                    # édition, mot de passe oublié, rôles, assistant
├── widgets/                         # GradientButton, RoleBadge, UserCard, AvatarWidget
├── theme/app_theme.dart             # Charte graphique (violet #7F5AF0…)
└── reservations/                    # Module Réservations de Salles (Y. Fadaoui)
    ├── data/reservation_database.dart   # tables salles, reservations, jours_feries
    ├── models/                          # Salle, Reservation (toMap / fromMap)
    ├── services/reservation_service.dart # recherche, réservation, modification (transactions)
    ├── services/jours_feries_service.dart # API Nager.Date + cache SQLite
    ├── screens/                         # réserver, mes réservations, modifier, salles (admin)
    └── ui/smartspace_style.dart         # composants de la charte
```

**Base de données partagée** : chaque module ajoute ses tables dans `DatabaseHelper._onCreate` (création) et `_onUpgrade` (migrations versionnées avec `CREATE TABLE IF NOT EXISTS` / `ALTER TABLE`).

### Intégrer un nouveau module (Sghaier, Manar, Louzeine)

1. Ajouter vos tables dans `lib/core/database_helper.dart` (`_onCreate`) et incrémenter `_version`
2. Créer `lib/<module>/` sur le modèle de `lib/reservations/`
3. Remplacer le placeholder dans `lib/core/home_shell.dart`
4. Vérifier les droits avec `ModuleAccess.canXxx(Session.roleEnum)`

---

## 🎨 Charte graphique

| Élément | Valeur |
|---|---|
| Violet primaire | `#7F5AF0` (en-têtes, boutons dégradés r=12, navigation active) |
| Gris-violet | `#2D2A4A` (textes secondaires) |
| Fond | `#F7F7FB` |
| Succès / Alerte | `#2ECC71` / `#FF6B6B` |
| Cartes | Blanc, coins 14 px, ombre légère |
| Typo | Roboto, 2 graisses (medium 20-22 titres / regular 14) |

---

## 🌐 Web services consommés (valeur ajoutée)

| Service | Usage |
|---|---|
| [DiceBear](https://www.dicebear.com) | Avatars des utilisateurs (fallback initiales offline) |
| [random.org](https://www.random.org) | Génération des codes OTP (entropie atmosphérique) |
| Gmail SMTP / [Brevo](https://www.brevo.com) | Envoi réel des OTP par email |
| [Nager.Date](https://date.nager.at) | Jours fériés tunisiens (module Réservations), mis en cache dans SQLite → fonctionne hors ligne |

Configuration de l'email : voir les constantes en tête de `lib/services/email_otp_service.dart` (laisser vide = mode démo simulé). ⚠️ Identifiants SMTP : à ne jamais versionner sur un dépôt public.

---

## 🚀 Lancer le projet

```bash
flutter pub get
flutter run          # émulateur Android/iOS
```

> `sqflite_common_ffi` est déjà configuré dans `main.dart` pour tester sur Windows/Linux sans téléphone.

---

## 🧰 Technologies

Flutter / Dart · SQLite (sqflite) · provider · SharedPreferences · crypto (SHA-256) · http · mailer · Form/TextFormField · ListView.builder · FutureBuilder/async-await · Navigator
