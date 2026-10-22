SET ROLE bank_owner;
SELECT setseed(0.42);

INSERT INTO core.customers (first_name, last_name, email, phone, birth_date, kyc_status, risk_level)
SELECT
    (ARRAY['Lucas','Emma','Leo','Chloé','Gabriel','Jade','Louis','Louise','Arthur','Alice'])[1 + (g % 10)],
    'Client_' || g,
    'client.' || g || '@novabank.fr',
    '+336' || lpad(g::text, 8, '0'),
    DATE '1955-01-01' + ((g * 19) % 18000),
    (ARRAY['VERIFIED','VERIFIED','PENDING']::core.kyc_status_enum[])[1 + (g % 3)],
    (ARRAY['LOW','LOW','MEDIUM','HIGH']::core.risk_level_enum[])[1 + (g % 4)]
FROM generate_series(1, 1000) AS g;

INSERT INTO core.accounts (customer_id, iban, account_type, balance, status, opened_at)
SELECT
    g,
    'FR763000600001' || lpad(g::text, 11, '0') || '89',
    (ARRAY['CHECKING','SAVINGS']::core.account_type_enum[])[1 + (g % 2)],
    0.00,
    CASE WHEN g % 50 = 0 THEN 'FROZEN'::core.account_status_enum ELSE 'ACTIVE'::core.account_status_enum END,
    TIMESTAMPTZ '2025-01-01 00:00:00+00'
FROM generate_series(1, 1000) AS g;

INSERT INTO core.transfers (from_account_id, to_account_id, amount, label, created_at)
SELECT
    ((g - 1) % 1000) + 1,
    (g % 1000) + 1,
    round((10 + random() * 90)::numeric, 2),
    'Virement #' || g,
    TIMESTAMPTZ '2025-01-02 00:00:00+00' + (g || ' minutes')::interval
FROM generate_series(1, 50000) AS g;

CREATE TEMP TABLE tmp_ops (
    temp_id bigint GENERATED ALWAYS AS IDENTITY,
    account_id bigint,
    tx_type core.tx_type_enum,
    amount numeric(14,2),
    signed_amount numeric(14,2),
    transfer_id bigint,
    created_at timestamptz
);

INSERT INTO tmp_ops (account_id, tx_type, amount, signed_amount, transfer_id, created_at)
SELECT g, 'DEPOSIT'::core.tx_type_enum, 50000.00, 50000.00, NULL, TIMESTAMPTZ '2025-01-01 01:00:00+00'
FROM generate_series(1, 1000) AS g;

INSERT INTO tmp_ops (account_id, tx_type, amount, signed_amount, transfer_id, created_at)
SELECT from_account_id, 'TRANSFER_OUT'::core.tx_type_enum, amount, -amount, transfer_id, created_at FROM core.transfers
UNION ALL
SELECT to_account_id, 'TRANSFER_IN'::core.tx_type_enum, amount, amount, transfer_id, created_at FROM core.transfers;

INSERT INTO tmp_ops (account_id, tx_type, amount, signed_amount, transfer_id, created_at)
SELECT
    ((g - 1) % 1000) + 1,
    CASE WHEN g % 2 = 0 THEN 'DEPOSIT'::core.tx_type_enum ELSE 'WITHDRAWAL'::core.tx_type_enum END,
    amt,
    CASE WHEN g % 2 = 0 THEN amt ELSE -amt END,
    NULL,
    TIMESTAMPTZ '2025-01-02 00:00:00+00' + ((g * 30) || ' seconds')::interval
FROM (SELECT g, round((5 + random() * 45)::numeric, 2) AS amt FROM generate_series(1, 899000) AS g) sub;

INSERT INTO core.transactions (account_id, tx_type, amount, balance_after, transfer_id, created_at)
SELECT
    account_id, tx_type, amount,
    sum(signed_amount) OVER (PARTITION BY account_id ORDER BY created_at, temp_id) AS balance_after,
    transfer_id, created_at
FROM tmp_ops ORDER BY created_at, temp_id;

WITH last_tx AS (
    SELECT DISTINCT ON (account_id) account_id, balance_after
    FROM core.transactions ORDER BY account_id, created_at DESC, tx_id DESC
)
UPDATE core.accounts a SET balance = l.balance_after FROM last_tx l WHERE a.account_id = l.account_id;

ANALYZE;

SELECT count(*) AS total_lignes FROM core.transactions;
