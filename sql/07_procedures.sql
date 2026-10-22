SET ROLE bank_owner;

-- 1. Procédure de virement sûr (anti-deadlock)
CREATE OR REPLACE PROCEDURE core.sp_transfer(
    p_from_account bigint,
    p_to_account bigint,
    p_amount numeric,
    p_label varchar DEFAULT 'Virement SEPA',
    INOUT p_transfer_id bigint DEFAULT NULL
)
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_first_lock bigint := LEAST(p_from_account, p_to_account);
    v_second_lock bigint := GREATEST(p_from_account, p_to_account);
    v_dummy bigint;
BEGIN
    -- 1. Vérification des paramètres
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'Le montant du virement doit être strictement positif.';
    END IF;

    IF p_from_account = p_to_account THEN
        RAISE EXCEPTION 'Les deux comptes d''un virement doivent être différents.';
    END IF;

    -- 2. Verrouillage dans l'ordre croissant des ID (évite le deadlock)
    SELECT account_id INTO v_dummy FROM core.accounts WHERE account_id = v_first_lock FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Compte % introuvable.', v_first_lock; END IF;

    SELECT account_id INTO v_dummy FROM core.accounts WHERE account_id = v_second_lock FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Compte % introuvable.', v_second_lock; END IF;

    -- 3. Écriture (les triggers créés précédemment se chargent des vérifications de solde et des alertes)
    INSERT INTO core.transfers (from_account_id, to_account_id, amount, label)
    VALUES (p_from_account, p_to_account, p_amount, p_label)
    RETURNING transfer_id INTO p_transfer_id;

    INSERT INTO core.transactions (account_id, tx_type, amount, balance_after, transfer_id)
    VALUES (p_from_account, 'TRANSFER_OUT', p_amount, 0, p_transfer_id);

    INSERT INTO core.transactions (account_id, tx_type, amount, balance_after, transfer_id)
    VALUES (p_to_account, 'TRANSFER_IN', p_amount, 0, p_transfer_id);
END;
$$;

-- 2. Procédure d'ouverture de compte
CREATE OR REPLACE PROCEDURE core.sp_open_account(
    p_customer_id bigint,
    p_iban varchar,
    p_account_type core.account_type_enum,
    p_initial_deposit numeric DEFAULT 0.00,
    INOUT p_account_id bigint DEFAULT NULL
)
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_kyc core.kyc_status_enum;
BEGIN
    SELECT kyc_status INTO v_kyc FROM core.customers WHERE customer_id = p_customer_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Client % introuvable.', p_customer_id; END IF;
    IF v_kyc <> 'VERIFIED' THEN RAISE EXCEPTION 'Ouverture refusée : le statut KYC du client % est %.', p_customer_id, v_kyc; END IF;
    IF p_initial_deposit < 0 THEN RAISE EXCEPTION 'Le dépôt initial ne peut pas être négatif.'; END IF;

    INSERT INTO core.accounts (customer_id, iban, account_type, balance, status)
    VALUES (p_customer_id, p_iban, p_account_type, 0.00, 'ACTIVE')
    RETURNING account_id INTO p_account_id;

    IF p_initial_deposit > 0 THEN
        INSERT INTO core.transactions (account_id, tx_type, amount, balance_after)
        VALUES (p_account_id, 'DEPOSIT', p_initial_deposit, 0.00);
    END IF;
END;
$$;

-- 3. Procédure de relevé de compte au format JSON
CREATE OR REPLACE PROCEDURE core.sp_account_statement(
    p_account_id bigint,
    INOUT p_statement jsonb DEFAULT NULL
)
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    PERFORM 1 FROM core.accounts WHERE account_id = p_account_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Compte % introuvable.', p_account_id; END IF;

    SELECT jsonb_agg(t) INTO p_statement
    FROM (
        SELECT tx_id, tx_type, amount, balance_after, created_at
        FROM core.transactions
        WHERE account_id = p_account_id
        ORDER BY created_at DESC
        LIMIT 20
    ) t;
END;
$$;

-- Accorder le droit d'exécution uniquement à l'application
GRANT EXECUTE ON PROCEDURE core.sp_transfer(bigint, bigint, numeric, varchar, bigint) TO grp_appli;
GRANT EXECUTE ON PROCEDURE core.sp_open_account(bigint, varchar, core.account_type_enum, numeric, bigint) TO grp_appli;
GRANT EXECUTE ON PROCEDURE core.sp_account_statement(bigint, jsonb) TO grp_appli;
