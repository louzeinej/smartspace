# 🎤 Guide de Présentation — Module 4: Gestion Networking (Manar Kalai)

> **Objectif** : Présenter ce module simplement à un jury ou enseignant (même avec 1/10 de connaissances en Flutter) et répondre facilement à leurs questions.

---

## 💡 1. Pitch du Projet (30 secondes)

> *"Bonjour ! Mon module est la **Gestion Networking**, le réseau social interne de l'entreprise SmartSpace (style mini-LinkedIn).*  
> *Il permet aux collaborateurs d'échanger des **actualités**, de publier des **annonces officielles épinglées**, de proposer des **formations** avec inscription en 1 clic, de lancer des **sondages interactifs** et de féliciter des collègues grâce à des **Kudos**."*

---

## 🧱 2. Comment ça marche dans le code ? (Explication très simple)

Pensez à ce module comme **4 étapes simples** :

```
 ┌─────────────────────────────────────────────────────────┐
 │ 1. La Base de Données (SQLite)                          │
 │    → Le coffre-fort dans le téléphone.                  │
 └──────────────────────────┬──────────────────────────────┘
                            │
 ┌──────────────────────────▼──────────────────────────────┐
 │ 2. Le Modèle de Données (Publication)                   │
 │    → Traduit les lignes SQL en objets Dart propres.     │
 └──────────────────────────┬──────────────────────────────┘
                            │
 ┌──────────────────────────▼──────────────────────────────┐
 │ 3. Le Moteur Métier (NetworkingService)                 │
 │    → La cuisine : calcule les votes, gère les likes,    │
 │      filtre les recherches et prépare l'export CSV.     │
 └──────────────────────────┬──────────────────────────────┘
                            │
 ┌──────────────────────────▼──────────────────────────────┐
 │ 4. L'Interface Visuelle (Flutter UI)                    │
 │    → Les cartes colorées, boutons et barres de filtre.  │
 └─────────────────────────────────────────────────────────┘
```

### Les 4 fichiers clés à retenir :
1. **`networking_database.dart`** : Crée les tables SQLite locales (`publications`, `publication_likes`, `publication_comments`, `poll_votes`, `training_enrollments`, `publication_bookmarks`). C'est **100% offline-first** !
2. **`publication.dart`** : Définit ce qu'est une publication (titre, message, type, auteur, nombre de likes, sondages, formations, kudos).
3. **`networking_service.dart`** : Exécute les requêtes SQL (ajouter un post, liker, voter dans un sondage, calculer la popularité).
4. **`networking_module.dart` & `publication_card.dart`** : Affiche le fil d'actualités avec la barre de recherche, les filtres par icône (`Formations 🎓`, `Sondages 📊`, `Kudos 🌟`) et les cartes réactives.

---

## ❓ 5 Questions Classiques du Jury & Réponses Simples

### 🔹 Q1 : "Comment l'application fonctionne-t-elle sans connexion Internet (Offline-first) ?"
> **Réponse** :  
> *"Toutes les données (messages, votes, likes, commentaires, favoris) sont directement stockées dans une base de données locale SQLite sur le téléphone (`smartspace.db`). Même en coupant le réseau, l'application reste 100% fonctionnelle."*

---

### 🔹 Q2 : "Comment affichez-vous le nom et la photo de l'auteur si les utilisateurs sont dans un autre module ?"
> **Réponse** :  
> *"Grâce à une jointure SQL (`INNER JOIN users u ON p.utilisateur_id = u.id`). Quand je lis une publication, SQLite va chercher le nom (`fullName`), le rôle et l'avatar de l'utilisateur directement dans la table `users` du Module 1."*

---

### 🔹 Q3 : "Comment fonctionnent les sondages interactifs ?"
> **Réponse** :  
> *"Quand un employé clique sur une option de sondage, la base SQLite enregistre son vote et empêche les votes doubles (`PRIMARY KEY (publication_id, utilisateur_id)`). L'application calcule automatiquement le pourcentage `(votes / total) * 100` et affiche une barre de progression animée."*

---

### 🔹 Q4 : "Qu'est-ce que le score de tendance (Tri par popularité) ?"
> **Réponse** :  
> *"C'est une formule mathématique simple qui calcule la popularité des sujets :  
> `Score = (Likes × 1) + (Commentaires × 2) + (Votes × 3) + (100 si Épinglé)`.  
> Les sujets les plus discutés remontent automatiquement en haut du fil."*

---

### 🔹 Q5 : "Que se passe-t-il quand un employé s'inscrit à une formation ?"
> **Réponse** :  
> *"Son inscription est enregistrée dans la table `training_enrollments`. Le responsable RH (`UserRole.rh`) ou l'Admin peut cliquer sur l'icône candidats (`👥`) pour voir la liste des inscrits et l'exporter en **fichier CSV** d'un seul clic."*

---

## 🎨 3 Points Forts UI/UX à Mettre en Avant pendant la Démo
1. **Cartes Adaptatives** : La carte change de style selon le type (verte pour les formations, rouge dégradé pour les Kudos, violette pour les sondages).
2. **Détection Automatique de Liens Web** : Si un message contient un lien `https://...`, une carte preview web est générée automatiquement avec le nom de domaine (`🌐 flutter.dev`).
3. **Tableau d'Honneur (Leaderboard 🏆)** : Classement en direct des collaborateurs les plus félicités avec médailles d'or 🥇, d'argent 🥈 et de bronze 🥉.
