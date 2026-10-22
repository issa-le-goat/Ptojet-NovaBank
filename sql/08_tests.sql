\set ON_ERROR_STOP off

\echo '=== TEST 1 : Profil Support (Vue masquée OK / Table refusée) ==='
SET ROLE usr_support;
SELECT * FROM core.v_support_customers LIMIT 1;
SELECT * FROM core.customers LIMIT 1; -- DOIT ECHOUER
RESET ROLE;

\echo '=== TEST 2 : Profil Appli (Procedure OK / Table refusée / Solde insuffisant refusé) ==='
SET ROLE usr_appli;
SELECT * FROM core.accounts LIMIT 1; -- DOIT ECHOUER
CALL core.sp_transfer(1, 2, 100.00, 'Test Appli', NULL);
CALL core.sp_transfer(1, 2, 999999.00, 'Test Solde', NULL); -- DOIT ECHOUER
RESET ROLE;

\echo '=== TEST 3 : Grand livre immuable (Modification interdite) ==='
SET ROLE bank_owner;
UPDATE core.transactions SET amount = 1 WHERE tx_id = 1; -- DOIT ECHOUER
DELETE FROM core.transactions WHERE tx_id = 1; -- DOIT ECHOUER
TRUNCATE core.transactions; -- DOIT ECHOUER

\echo '=== TEST 4 : Alertes Fraudes (Retrait > 5000 et 5 virements en 10 min) ==='
INSERT INTO core.transactions (account_id, tx_type, amount, balance_after) VALUES (2, 'WITHDRAWAL', 6000.00, 0);

CALL core.sp_transfer(3, 4, 10.00, 'Rafale 1', NULL);
CALL core.sp_transfer(3, 4, 10.00, 'Rafale 2', NULL);
CALL core.sp_transfer(3, 4, 10.00, 'Rafale 3', NULL);
CALL core.sp_transfer(3, 4, 10.00, 'Rafale 4', NULL);
CALL core.sp_transfer(3, 4, 10.00, 'Rafale 5', NULL);

\echo '=== VERIFICATION DES ALERTES PAR L AUDITEUR ==='
SET ROLE usr_auditeur;
SELECT * FROM core.fraud_alerts ORDER BY alert_id DESC LIMIT 2;
RESET ROLE;
