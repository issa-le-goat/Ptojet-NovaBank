#!/usr/bin/env bash
set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo "Erreur : ce script doit être exécuté en tant que root (sudo)." >&2
    exit 1
fi

echo "=== [1/5] Mise à jour et installation des paquets ==="
apt-get update -y
apt-get install -y postgresql postgresql-client postgresql-contrib ufw

echo "=== [2/5] Détection du cluster PostgreSQL ==="
PG_VER=$(psql -V | awk '{print $3}' | cut -d. -f1)
CONF_DIR="/etc/postgresql/${PG_VER}/main/conf.d"
HBA_FILE="/etc/postgresql/${PG_VER}/main/pg_hba.conf"

echo "=== [3/5] Configuration dans conf.d ==="
mkdir -p "$CONF_DIR"
cat > "${CONF_DIR}/99-novabank.conf" << 'PGCONF'
listen_addresses = 'localhost,192.168.204.10'
password_encryption = 'scram-sha-256'
log_connections = on
log_statement = 'ddl'
PGCONF

echo "=== [4/5] Configuration de pg_hba.conf ==="
cp "$HBA_FILE" "${HBA_FILE}.bak"
cat > "$HBA_FILE" << 'HBAEOF'
# TYPE  DATABASE   USER                                      ADDRESS          METHOD
# (1) Administrateur local postgres par fichier-socket
local   all        postgres                                                   peer

# (2) Propriétaire de la base et application depuis la VM seulement
host    bankdb     bank_owner,+grp_appli                     127.0.0.1/32     scram-sha-256
host    bankdb     bank_owner,+grp_appli                     ::1/128          scram-sha-256

# (3) Analystes, support et auditeurs depuis le réseau d'administration (et localhost pour tests)
host    bankdb     +grp_analyste,+grp_support,+grp_auditeur  127.0.0.1/32     scram-sha-256
host    bankdb     +grp_analyste,+grp_support,+grp_auditeur  192.168.204.0/24 scram-sha-256

# (4) Tout le reste est refusé
local   all        all                                                        reject
host    all        all                                       0.0.0.0/0        reject
host    all        all                                       ::/0             reject
HBAEOF

systemctl restart postgresql

echo "=== [5/5] Configuration du pare-feu UFW ==="
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH Admin'
ufw allow from 127.0.0.1 to any port 5432 proto tcp comment 'PG Local'
ufw allow from 192.168.204.0/24 to any port 5432 proto tcp comment 'PG Host-Only Admin'
ufw --force enable

echo "=== E1 terminé avec succès ! ==="
