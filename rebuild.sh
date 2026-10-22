#!/usr/bin/env bash
set -euo pipefail

read -r -p "ATTENTION : Reconstruire toute la base de données ? (oui/non) : " confirm
if [[ "$confirm" != "oui" ]]; then exit 0; fi

echo "=== 1. Suppression ==="
sudo -u postgres psql << 'EOSQL'
DROP DATABASE IF EXISTS bankdb;
DROP ROLE IF EXISTS usr_analyste, usr_support, usr_appli, usr_auditeur;
DROP ROLE IF EXISTS grp_analyste, grp_support, grp_appli, grp_auditeur;
DROP ROLE IF EXISTS bank_owner;
EOSQL

echo "=== 2. Reconstruction ==="
sudo -u postgres psql < sql/00_init_db_and_roles.sql
sudo -u postgres psql -d bankdb < sql/02_tables.sql
sudo -u postgres psql -d bankdb < sql/02_seed_data.sql
sudo -u postgres psql -d bankdb < sql/03_04_views_and_grants.sql
sudo -u postgres psql -d bankdb < sql/05_indexes.sql
sudo -u postgres psql -d bankdb < sql/06_triggers.sql
sudo -u postgres psql -d bankdb < sql/07_procedures.sql

echo "=== Base reconstruite avec succès ! ==="
