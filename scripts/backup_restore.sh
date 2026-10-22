#!/usr/bin/env bash
set -euo pipefail

BACKUP="/tmp/bankdb.dump"

echo "=== 1. Sauvegarde (pg_dump -Fc) ==="
sudo -u postgres pg_dump -Fc -d bankdb > "$BACKUP"
ls -lh "$BACKUP"

echo "=== 2. Restauration dans une base temporaire ==="
sudo -u postgres dropdb --if-exists bankdb_test
sudo -u postgres createdb -O bank_owner bankdb_test
sudo -u postgres pg_restore -d bankdb_test < "$BACKUP"

echo "=== 3. Comparaison du nombre de transactions ==="
sudo -u postgres psql -d bankdb -c "SELECT 'Originale' as base, count(*) FROM core.transactions;"
sudo -u postgres psql -d bankdb_test -c "SELECT 'Restauration' as base, count(*) FROM core.transactions;"

sudo -u postgres dropdb bankdb_test
rm -f "$BACKUP"
