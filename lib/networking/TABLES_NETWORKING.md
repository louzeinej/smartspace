# 📊 Schéma des Tables SQLite — Module 4: Networking (Manar Kalai)

> Diagramme visuel et description simple des **7 tables SQLite** utilisées par le module Networking.

---

## 🗺️ Diagramme des Relations (Vue d'ensemble)

```
                       ┌──────────────────────┐
                       │   users (Module 1)   │
                       │ id, fullName, email  │
                       └──────────┬───────────┘
                                  │ (Auteur / Participant)
                                  ▼
 ┌─────────────────────────────────────────────────────────────────┐
 │                          PUBLICATIONS                           │
 │ id | utilisateur_id | titre | contenu | type | date_publication │
 │ is_pinned | likes_count | kudos_destinataire_id | kudos_badge   │
 │ formation_date | formation_competence                           │
 └──────┬────────────┬─────────────┬─────────────┬────────────┬────┘
        │            │             │             │            │
        ▼            ▼             ▼             ▼            ▼
┌──────────────┐┌───────────┐┌───────────┐┌────────────┐┌───────────┐
│PUBLICATION_  ││PUBLICATION││POLL_      ││TRAINING_   ││PUBLICATION│
│LIKES         ││COMMENTS   ││OPTIONS    ││ENROLLMENTS ││BOOKMARKS  │
│pub_id, usr_id││id, pub_id ││id, pub_id ││pub_id,     ││pub_id,    │
└──────────────┘│usr_id, txt││txt, votes ││usr_id, date││usr_id, date│
                └───────────┘└─────┬─────┘└────────────┘└───────────┘
                                   │
                                   ▼
                            ┌────────────┐
                            │POLL_VOTES  │
                            │pub_id,     │
                            │opt_id,     │
                            │usr_id      │
                            └────────────┘
```

---

## 📋 Detail des 7 Tables SQLite

### 1. 📝 Table `publications` (Table Principale)
Stocke tous les types de publications (Actualités, Annonces, Formations, Sondages, Kudos).

| Colonne | Type | Clé / Contrainte | Rôle / Description |
|---|---|---|---|
| `id` | INTEGER | PRIMARY KEY | Identifiant unique de la publication |
| `utilisateur_id` | INTEGER | FK -> `users(id)` | L'auteur du message |
| `titre` | TEXT | NOT NULL | Titre de la publication |
| `contenu` | TEXT | NOT NULL | Message / Description |
| `type` | TEXT | NOT NULL | `Actualité`, `Annonce`, `Formation`, `Sondage`, `Kudos` |
| `date_publication` | TEXT | NOT NULL | Horodatage ISO |
| `is_pinned` | INTEGER | DEFAULT 0 | 1 si annonce épinglée par l'Admin, 0 sinon |
| `likes_count` | INTEGER | DEFAULT 0 | Compteur total de j'aime |
| `kudos_destinataire_id`| INTEGER | FK -> `users(id)` | Le collègue félicité (pour Kudos) |
| `kudos_destinataire_nom`| TEXT | NULL | Nom du collègue félicité |
| `kudos_badge` | TEXT | NULL | Badge attribué (ex: `🌟 Esprit d'équipe`) |
| `formation_date` | TEXT | NULL | Date/heure de la formation |
| `formation_competence`| TEXT | NULL | Sujet/Compétence ciblée |

---

### 2. ❤️ Table `publication_likes` (Mentions J'aime)
Stocke quel utilisateur a aimé quelle publication (empêche les doublons).

| Colonne | Type | Clé | Description |
|---|---|---|---|
| `publication_id` | INTEGER | PK, FK -> `publications(id)` | La publication likée |
| `utilisateur_id` | INTEGER | PK, FK -> `users(id)` | L'utilisateur qui a liké |

---

### 3. 💬 Table `publication_comments` (Commentaires)
Stocke la liste des commentaires sous chaque publication.

| Colonne | Type | Clé | Description |
|---|---|---|---|
| `id` | INTEGER | PRIMARY KEY | Identifiant unique du commentaire |
| `publication_id` | INTEGER | FK -> `publications(id)` | La publication commentée |
| `utilisateur_id` | INTEGER | FK -> `users(id)` | L'auteur du commentaire |
| `commentaire` | TEXT | NOT NULL | Le texte du commentaire |
| `date_commentaire` | TEXT | NOT NULL | Date d'envoi ISO |

---

### 4. 📊 Table `poll_options` (Choix des Sondages)
Stocke les choix possibles pour un sondage.

| Colonne | Type | Clé | Description |
|---|---|---|---|
| `id` | INTEGER | PRIMARY KEY | Identifiant unique de l'option |
| `publication_id` | INTEGER | FK -> `publications(id)` | Le sondage concerné |
| `option_texte` | TEXT | NOT NULL | Le texte de l'option (ex: `🏞️ Randonnée`) |
| `votes_count` | INTEGER | DEFAULT 0 | Nombre total de votes pour ce choix |

---

### 5. 🗳️ Table `poll_votes` (Votes des Sondages)
Stocke le vote individuel de chaque employé (1 seul vote par employé par sondage).

| Colonne | Type | Clé | Description |
|---|---|---|---|
| `publication_id` | INTEGER | PK, FK -> `publications(id)` | Le sondage voté |
| `utilisateur_id` | INTEGER | PK, FK -> `users(id)` | L'employé votant |
| `option_id` | INTEGER | FK -> `poll_options(id)` | L'option choisie |

---

### 6. 🎓 Table `training_enrollments` (Inscriptions aux Formations)
Stocke les employés inscrits aux offres de formation.

| Colonne | Type | Clé | Description |
|---|---|---|---|
| `publication_id` | INTEGER | PK, FK -> `publications(id)` | La formation |
| `utilisateur_id` | INTEGER | PK, FK -> `users(id)` | L'employé inscrit |
| `date_inscription` | TEXT | NOT NULL | Date de l'inscription |

---

### 7. 🔖 Table `publication_bookmarks` (Mes Favoris)
Stocke les publications enregistrées par un employé.

| Colonne | Type | Clé | Description |
|---|---|---|---|
| `publication_id` | INTEGER | PK, FK -> `publications(id)` | La publication sauvegardée |
| `utilisateur_id` | INTEGER | PK, FK -> `users(id)` | L'employé qui l'a mise en favori |
| `date_ajout` | TEXT | NOT NULL | Date de mise en favori |
