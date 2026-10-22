SET ROLE bank_owner;

-- 1. Trigger de calcul et mise à jour automatique du solde
CREATE OR REPLACE FUNCTION core.fn_update_account_balance()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_current_balance numeric(14,2);
    v_status core.account_status_enum;
    v_new_balance numeric(14,2);
BEGIN
    -- Verrouillage de la ligne du compte (SELECT FOR UPDATE)
    SELECT balance, status INTO v_current_balance, v_status
    FROM core.accounts
    WHERE account_id = NEW.account_id
    FOR UPDATE;

    IF NOT FOUND THEN RAISE EXCEPTION 'Compte % introuvable', NEW.account_id; END IF;
    IF v_status <> 'ACTIVE' THEN RAISE EXCEPTION 'Opération refusée : le compte % a le statut %', NEW.account_id, v_status; END IF;

    -- Calcul du nouveau solde
    IF NEW.tx_type IN ('DEPOSIT', 'TRANSFER_IN') THEN
        v_new_balance := v_current_balance + NEW.amount;
    ELSIF NEW.tx_type IN ('WITHDRAWAL', 'TRANSFER_OUT') THEN
        v_new_balance := v_current_balance - NEW.amount;
    END IF;

    -- Rejet si le compte tombe en négatif
    IF v_new_balance < 0 THEN
        RAISE EXCEPTION 'Solde insuffisant sur le compte % (solde actuel: %)', NEW.account_id, v_current_balance;
    END IF;

    -- Enregistrement sur la transaction et mise à jour du compte
    NEW.balance_after := v_new_balance;
    UPDATE core.accounts SET balance = v_new_balance WHERE account_id = NEW.account_id;
    
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_transactions_before_balance
BEFORE INSERT ON core.transactions
FOR EACH ROW EXECUTE FUNCTION core.fn_update_account_balance();


-- 2. Trigger d'immuabilité du grand livre (Interdit UPDATE, DELETE, TRUNCATE)
CREATE OR REPLACE FUNCTION core.fn_prevent_tx_modification()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Grand livre immuable : l''opération % est strictement interdite.', TG_OP;
END;
$$;

CREATE TRIGGER trg_transactions_before_immutable_row
BEFORE UPDATE OR DELETE ON core.transactions
FOR EACH ROW EXECUTE FUNCTION core.fn_prevent_tx_modification();

CREATE TRIGGER trg_transactions_before_immutable_stmt
BEFORE TRUNCATE ON core.transactions
FOR EACH STATEMENT EXECUTE FUNCTION core.fn_prevent_tx_modification();


-- 3. Trigger de détection des fraudes (Retraits > 5000 ou 5 virements sortants en 10 min)
CREATE OR REPLACE FUNCTION core.fn_detect_fraud()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_recent_transfers int;
BEGIN
    IF NEW.tx_type = 'WITHDRAWAL' AND NEW.amount >= 5000 THEN
        INSERT INTO core.fraud_alerts (account_id, tx_id, rule_code)
        VALUES (NEW.account_id, NEW.tx_id, 'HIGH_WITHDRAWAL_5000');
    END IF;

    IF NEW.tx_type = 'TRANSFER_OUT' THEN
        SELECT count(*) INTO v_recent_transfers
        FROM core.transactions
        WHERE account_id = NEW.account_id AND tx_type = 'TRANSFER_OUT'
          AND created_at >= (NEW.created_at - INTERVAL '10 minutes');

        IF v_recent_transfers >= 5 THEN
            INSERT INTO core.fraud_alerts (account_id, tx_id, rule_code)
            VALUES (NEW.account_id, NEW.tx_id, 'VELOCITY_5_TRANSFERS_10MIN');
        END IF;
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_transactions_after_fraud
AFTER INSERT ON core.transactions
FOR EACH ROW EXECUTE FUNCTION core.fn_detect_fraud();


-- 4. Trigger d'audit unique et générique (multi-tables)
CREATE OR REPLACE FUNCTION core.fn_audit_log()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit.audit_log (table_name, operation, old_data, new_data, db_user)
        VALUES (TG_TABLE_NAME, TG_OP, NULL, to_jsonb(NEW), session_user);
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit.audit_log (table_name, operation, old_data, new_data, db_user)
        VALUES (TG_TABLE_NAME, TG_OP, to_jsonb(OLD), to_jsonb(NEW), session_user);
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit.audit_log (table_name, operation, old_data, new_data, db_user)
        VALUES (TG_TABLE_NAME, TG_OP, to_jsonb(OLD), NULL, session_user);
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_customers_after_audit AFTER INSERT OR UPDATE OR DELETE ON core.customers FOR EACH ROW EXECUTE FUNCTION core.fn_audit_log();
CREATE TRIGGER trg_accounts_after_audit AFTER INSERT OR DELETE ON core.accounts FOR EACH ROW EXECUTE FUNCTION core.fn_audit_log();
CREATE TRIGGER trg_accounts_after_update_audit AFTER UPDATE ON core.accounts FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status) EXECUTE FUNCTION core.fn_audit_log();
CREATE TRIGGER trg_transfers_after_audit AFTER INSERT ON core.transfers FOR EACH ROW EXECUTE FUNCTION core.fn_audit_log();
