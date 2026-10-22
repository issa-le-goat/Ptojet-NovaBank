# NovaBank Core - Projet PostgreSQL

Bienvenue dans le dépôt du projet **NovaBank Core**. Ce projet consiste à créer, sécuriser et automatiser la base de données d'une banque en ligne avec PostgreSQL sur une machine virtuelle Linux (Ubuntu Server).

## Architecture des fichiers
* `scripts/` : Scripts Bash pour l'administration du serveur (`01_install_server.sh`) et la gestion des sauvegardes (`backup_restore.sh`).
* `sql/` : Scripts SQL numérotés contenant toute la logique de la base (schémas, tables, données de test, vues, droits, index, triggers, procédures).
* `screenshots/` : Les captures d'écran prouvant le bon fonctionnement de chaque étape.
* `rebuild.sh` : Le script maître permettant de tout effacer et reconstruire de zéro.
* `.gitignore` et `.gitattributes` : Configurations Git (blocage des mots de passe et gestion des fins de ligne `LF`).

## Comment tout refaire depuis zéro
Pour reconstruire entièrement le projet sur une machine fraîche :
1. Clonez ce dépôt.
2. Exécutez le script d'installation du serveur (en root) : `sudo ./scripts/01_install_server.sh`
3. Lancez le script de reconstruction totale (qui exécutera tous les scripts SQL dans l'ordre) : `./rebuild.sh`

## Schéma des tables
La base `bankdb` est répartie en deux schémas (`core` et `audit`) et contient 6 tables :
* `core.customers` : Informations clients (contraintes sur l'âge majeur et la validité de l'email).
* `core.accounts` : Comptes bancaires (liés aux clients, solde toujours positif et mis à jour automatiquement).
* `core.transfers` : Ordres de virements (entre deux comptes distincts avec montant positif).
* `core.transactions` : Grand livre immuable des écritures (dépôts, retraits, transferts entrants/sortants).
* `core.fraud_alerts` : Alertes automatiques de fraude (alimentées par les triggers).
* `audit.audit_log` : Historique inaltérable de toutes les modifications (INSERT, UPDATE, DELETE).

## Gestion des droits (Principe du moindre privilège)
* `bank_owner` : Propriétaire de la base (droits complets).
* `usr_analyste` (via `grp_analyste`) : Lecture sur les vues statistiques et les tables de transactions anonymisées. Aucun accès à la table clients.
* `usr_support` (via `grp_support`) : Lecture de la vue client sécurisée (emails masqués, mots de passe hashés), et droit exclusif de modifier le statut d'un compte (UPDATE).
* `usr_appli` (via `grp_appli`) : Aucun droit direct sur les tables. Droit d'exécution (`EXECUTE`) uniquement sur les procédures stockées (virements, ouvertures, relevés).
* `usr_auditeur` (via `grp_auditeur`) : Lecture seule sur les alertes de fraude, les transactions et les journaux d'audit.

## Liste des captures d'écran fournies
1. `E1_serveur_parefeu.png` : Statut UFW et validation des règles `pg_hba.conf`.
2. `E2_1_million_lignes.png` : Preuve du million d'écritures générées avec `generate_series`.
3. `E3_matrice_droits.png` : Matrice booléenne validant les permissions strictes de chaque profil.
4. `E5_index_explain.png` : Comparaison des plans d'exécution `Seq Scan` vs `Index/Bitmap Scan`.
5. `E8_tests_securite.png` : Preuve que les actions interdites (modification du grand livre, accès non autorisés) sont bloquées par la base.
6. `E8_backup_restore.png` : Validation de la restauration via `pg_dump -Fc` et `pg_restore`.

## Déclaration d'utilisation de l'IA
Pour réaliser ce projet, une intelligence artificielle a été utilisée en tant qu'assistant de programmation. Elle m'a aidé à :
* Structurer les scripts Bash d'installation et automatiser la restauration.
* Diagnostiquer les problèmes de configuration réseau (Netplan sur VMware).
Je suis en capacité de comprendre et d'expliquer chaque ligne de code présente dans ce dépôt.
