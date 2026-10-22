SET ROLE bank_owner;

-- ==========================================
-- E4 : LES VUES
-- ==========================================

-- Fonction de masquage pour le support
CREATE OR REPLACE FUNCTION core.fn_mask_email(p_email varchar)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
    SELECT left(p_email, 2) || '***' || substr(p_email, strpos(p_email, '@'));
$$;

-- 1. Vue qui cache des données (pour le support)
CREATE OR REPLACE VIEW core.v_support_customers WITH (security_barrier = true) AS
SELECT
    customer_id,
    first_name,
    left(last_name, 1) || '.' AS last_name_masked,
    core.fn_mask_email(email) AS email_masked,
    md5(phone) AS phone_hash,
    kyc_status,
    risk_level
FROM core.customers;

-- 2. Vue modifiable avec une limite (empêche de passer un compte à CLOSED via la vue)
CREATE OR REPLACE VIEW core.v_support_accounts AS
SELECT account_id, customer_id, iban, account_type, balance, status, opened_at
FROM core.accounts
WHERE status IN ('ACTIVE', 'FROZEN')
WITH LOCAL CHECK OPTION;

-- 3. Vue enregistrée (matérialisée) pour les analystes + index unique pour CONCURRENTLY
CREATE MATERIALIZED VIEW core.mv_daily_stats AS
SELECT
    date_trunc('day', created_at)::date AS tx_day,
    tx_type,
    count(*) AS tx_count,
    sum(amount) AS total_amount
FROM core.transactions
GROUP BY 1, 2;

CREATE UNIQUE INDEX idx_mv_daily_stats_unique ON core.mv_daily_stats (tx_day, tx_type);
REFRESH MATERIALIZED VIEW CONCURRENTLY core.mv_daily_stats;

-- ==========================================
-- E3 : LES DROITS (Moindre privilège)
-- ==========================================
RESET ROLE;

-- Fermer les portes à PUBLIC
REVOKE ALL ON DATABASE bankdb FROM PUBLIC;
REVOKE ALL ON SCHEMA public, core, audit FROM PUBLIC;

-- Porte 1 : Connexion à la base
GRANT CONNECT ON DATABASE bankdb TO grp_analyste, grp_support, grp_appli, grp_auditeur;

-- Limite de temps de requête (statement_timeout) par profil
ALTER ROLE grp_analyste SET statement_timeout = '10s';
ALTER ROLE grp_support  SET statement_timeout = '5s';
ALTER ROLE grp_appli    SET statement_timeout = '3s';
ALTER ROLE grp_auditeur SET statement_timeout = '15s';

SET ROLE bank_owner;

-- Porte 2 : Entrer dans le schéma (USAGE)
GRANT USAGE ON SCHEMA core TO grp_analyste, grp_support, grp_appli, grp_auditeur;
GRANT USAGE ON SCHEMA audit TO grp_auditeur;

-- Porte 3 : Droits stricts par métier
GRANT SELECT ON core.mv_daily_stats, core.accounts, core.transactions, core.transfers TO grp_analyste;

GRANT EXECUTE ON FUNCTION core.fn_mask_email(varchar) TO grp_support;
GRANT SELECT ON core.v_support_customers TO grp_support;
GRANT SELECT, UPDATE (status) ON core.v_support_accounts TO grp_support;

-- L'appli n'a aucun droit sur les tables (appellera uniquement les procédures)
REVOKE ALL ON ALL TABLES IN SCHEMA core, audit FROM grp_appli;

GRANT SELECT ON audit.audit_log, core.fraud_alerts, core.transactions, core.transfers TO grp_auditeur;

-- Privilèges par défaut pour bloquer les futurs objets
ALTER DEFAULT PRIVILEGES FOR ROLE bank_owner IN SCHEMA core REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE bank_owner IN SCHEMA audit REVOKE ALL ON TABLES FROM PUBLIC;

RESET ROLE;

-- Matrice de preuve des droits
SELECT
    r.rolname AS profil,
    has_table_privilege(r.rolname, 'core.customers', 'SELECT') AS read_customers,
    has_table_privilege(r.rolname, 'core.v_support_customers', 'SELECT') AS read_masked_view,
    has_table_privilege(r.rolname, 'core.transactions', 'SELECT') AS read_tx,
    has_table_privilege(r.rolname, 'core.transactions', 'DELETE') AS delete_tx,
    has_table_privilege(r.rolname, 'audit.audit_log', 'SELECT') AS read_audit
FROM pg_roles r
WHERE r.rolname IN ('usr_analyste', 'usr_support', 'usr_appli', 'usr_auditeur');
