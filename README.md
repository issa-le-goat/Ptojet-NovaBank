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

<img width="829" height="517" alt="Capture d&#39;écran 2026-10-22 170438" src="https://github.com/user-attachments/assets/6601aaec-bfa3-4756-87f9-5dcc1e004587" />
<img width="944" height="1020" alt="Capture d&#39;écran 2026-10-22 170410" src="https://github.com/user-attachments/assets/8f3653be-cab6-442a-8e98-13330ad09366" />
<img width="924" height="913" alt="Capture d&#39;écran 2026-10-22 170403" src="https://github.com/user-attachments/assets/b5b79947-5b9e-48ca-812b-228bf609dc33" />
<img width="952" height="913" alt="Capture d&#39;écran 2026-10-22 170334" src="https://github.com/user-attachments/assets/46b40201-ed20-499b-96d9-6305cc2a96d0" />
<img width="946" height="1093" alt="Capture d&#39;écran 2026-10-22 170321" src="https://github.com/user-attachments/assets/749caf81-8313-48f4-a833-a3db0b0698a1" />
<img width="939" height="615" alt="Capture d&#39;écran 2026-10-22 170232" src="https://github.com/user-attachments/assets/5d6c22f3-da9d-4270-8e3f-bf2240133e97" />
<img width="1310" height="866" alt="Capture d&#39;écran 2026-10-22 165750" src="https://github.com/user-attachments/assets/6a2dcd12-38ec-49a9-98ac-9228ec35d994" />
<img width="12" height="4" alt="Capture d&#39;écran 2026-10-22 165735" src="https://github.com/user-attachments/assets/83cb1948-f68e-4158-8dd8-1a308f863164" />
<img width="950" height="713" alt="Capture d&#39;écran 2026-10-22 165143" src="https://github.com/user-attachments/assets/fe4e0b05-5803-44f2-9cbd-d38dc7d0fee6" />
<img width="499" height="122" alt="Capture d&#39;écran 2026-10-22 164804" src="https://github.com/user-attachments/assets/df505397-ab41-413d-b74a-6ec7354f36fb" />
<img width="932" height="1091" alt="Capture d&#39;écran 2026-10-22 164554" src="https://github.com/user-attachments/assets/70a296f7-7b03-4257-9703-e7b028f05265" />
<img width="642" height="377" alt="Capture d&#39;écran 2026-10-22 164330" src="https://github.com/user-attachments/assets/9452857a-3e59-4a57-bf9a-0597a5fa8e97" />
<img width="896" height="859" alt="Capture d&#39;écran 2026-10-22 164111" src="https://github.com/user-attachments/assets/56d6bba2-883b-4358-83ac-fbddd616b01d" />
<img width="641" height="357" alt="Capture d&#39;écran 2026-10-22 171341" src="https://github.com/user-attachments/assets/0f69cd15-8ba2-4ae8-95e4-1fef5e20840e" />
<img width="950" height="1034" alt="Capture d&#39;écran 2026-10-22 171257" src="https://github.com/user-attachments/assets/5b56d767-aeeb-4892-94e2-7496264315de" />
<img width="629" height="177" alt="Capture d&#39;écran 2026-10-22 171135" src="https://github.com/user-attachments/assets/412a4248-5968-4da9-9127-e57a1cb47309" />
<img width="683" height="297" alt="Capture d&#39;écran 2026-10-22 171041" src="https://github.com/user-attachments/assets/0984069e-2bab-46e9-b032-59b458303711" />
<img width="953" height="1105" alt="Capture d&#39;écran 2026-10-22 170940" src="https://github.com/user-attachments/assets/86fe2089-bc1c-4c57-b3ea-f827895251b4" />
<img width="905" height="1018" alt="Capture d&#39;écran 2026-10-22 170739" src="https://github.com/user-attachments/assets/b3b08218-6be7-49ce-9869-b152f6560e84" />

