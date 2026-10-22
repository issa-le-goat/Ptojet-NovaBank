SET ROLE bank_owner;

\echo '=== MESURES AVANT INDEX (Seq Scan attendu) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT tx_id, tx_type, amount, balance_after, created_at
FROM core.transactions WHERE account_id = 42 ORDER BY created_at DESC LIMIT 20;

EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, email FROM core.customers WHERE lower(email) = lower('CLIENT.500@novabank.fr');

EXPLAIN (ANALYZE, BUFFERS)
SELECT account_id, iban, balance FROM core.accounts WHERE status = 'FROZEN';

EXPLAIN (ANALYZE, BUFFERS)
SELECT sum(amount) FROM core.transactions
WHERE created_at >= TIMESTAMPTZ '2025-03-01 00:00:00+00'
  AND created_at <  TIMESTAMPTZ '2025-04-01 00:00:00+00';

\echo '=== CREATION DES 4 INDEX UTILES + 1 INDEX INUTILE ==='
-- 1. Relevé de compte filtré par compte et trié par date
CREATE INDEX idx_transactions_account_date ON core.transactions (account_id, created_at DESC);

-- 2. Recherche insensible à la casse
CREATE INDEX idx_customers_lower_email ON core.customers (lower(email));

-- 3. Index partiel sur les comptes gelés (petite minorité des lignes)
CREATE INDEX idx_accounts_frozen ON core.accounts (account_id) WHERE status = 'FROZEN';

-- 4. Index BRIN sur created_at pour une somme sur un mois
CREATE INDEX idx_transactions_created_brin ON core.transactions USING brin (created_at);

-- Bonus E5 : Index inutile sur une colonne qui n'a que 4 valeurs différentes
CREATE INDEX idx_transactions_useless_type ON core.transactions (tx_type);

ANALYZE;

\echo '=== MESURES APRES INDEX (Index Scan / Bitmap Index Scan attendus) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT tx_id, tx_type, amount, balance_after, created_at
FROM core.transactions WHERE account_id = 42 ORDER BY created_at DESC LIMIT 20;

EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, email FROM core.customers WHERE lower(email) = lower('CLIENT.500@novabank.fr');

EXPLAIN (ANALYZE, BUFFERS)
SELECT account_id, iban, balance FROM core.accounts WHERE status = 'FROZEN';

EXPLAIN (ANALYZE, BUFFERS)
SELECT sum(amount) FROM core.transactions
WHERE created_at >= TIMESTAMPTZ '2025-03-01 00:00:00+00'
  AND created_at <  TIMESTAMPTZ '2025-04-01 00:00:00+00';

\echo '=== TEST DE L INDEX INUTILE (PostgreSQL préfère Seq Scan !) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM core.transactions WHERE tx_type = 'DEPOSIT';

\echo '=== TAILLE DES INDEX ==='
SELECT indexrelname AS index_name, pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes WHERE schemaname = 'core';
