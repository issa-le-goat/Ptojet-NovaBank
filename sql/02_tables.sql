SET ROLE bank_owner;

CREATE TYPE core.kyc_status_enum AS ENUM ('PENDING', 'VERIFIED', 'REJECTED');
CREATE TYPE core.risk_level_enum AS ENUM ('LOW', 'MEDIUM', 'HIGH');
CREATE TYPE core.account_type_enum AS ENUM ('CHECKING', 'SAVINGS');
CREATE TYPE core.account_status_enum AS ENUM ('ACTIVE', 'FROZEN', 'CLOSED');
CREATE TYPE core.tx_type_enum AS ENUM ('DEPOSIT', 'WITHDRAWAL', 'TRANSFER_IN', 'TRANSFER_OUT');
CREATE TYPE core.alert_status_enum AS ENUM ('OPEN', 'INVESTIGATING', 'RESOLVED');

CREATE TABLE core.customers (
    customer_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name varchar(100) NOT NULL,
    last_name varchar(100) NOT NULL,
    email varchar(255) NOT NULL UNIQUE,
    phone varchar(50) NOT NULL,
    birth_date date NOT NULL,
    kyc_status core.kyc_status_enum NOT NULL DEFAULT 'PENDING',
    risk_level core.risk_level_enum NOT NULL DEFAULT 'LOW',
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_customers_email_valid CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT ck_customers_adult CHECK (birth_date <= (CURRENT_DATE - INTERVAL '18 years'))
);

CREATE TABLE core.accounts (
    account_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id bigint NOT NULL REFERENCES core.customers(customer_id),
    iban varchar(34) NOT NULL UNIQUE,
    account_type core.account_type_enum NOT NULL DEFAULT 'CHECKING',
    balance numeric(14,2) NOT NULL DEFAULT 0.00,
    status core.account_status_enum NOT NULL DEFAULT 'ACTIVE',
    opened_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_accounts_balance_positive CHECK (balance >= 0)
);

CREATE TABLE core.transfers (
    transfer_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    from_account_id bigint NOT NULL REFERENCES core.accounts(account_id),
    to_account_id bigint NOT NULL REFERENCES core.accounts(account_id),
    amount numeric(14,2) NOT NULL,
    label varchar(255) NOT NULL DEFAULT 'Virement SEPA',
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_transfers_amount_positive CHECK (amount > 0),
    CONSTRAINT ck_transfers_different_accounts CHECK (from_account_id <> to_account_id)
);

CREATE TABLE core.transactions (
    tx_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id bigint NOT NULL REFERENCES core.accounts(account_id),
    tx_type core.tx_type_enum NOT NULL,
    amount numeric(14,2) NOT NULL,
    balance_after numeric(14,2) NOT NULL,
    transfer_id bigint REFERENCES core.transfers(transfer_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_transactions_amount_positive CHECK (amount > 0),
    CONSTRAINT ck_transactions_balance_after_positive CHECK (balance_after >= 0)
);

CREATE TABLE core.fraud_alerts (
    alert_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id bigint NOT NULL REFERENCES core.accounts(account_id),
    tx_id bigint REFERENCES core.transactions(tx_id),
    rule_code varchar(50) NOT NULL,
    status core.alert_status_enum NOT NULL DEFAULT 'OPEN',
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_fraud_alerts_rule CHECK (rule_code IN ('HIGH_WITHDRAWAL_5000', 'VELOCITY_5_TRANSFERS_10MIN'))
);

CREATE TABLE audit.audit_log (
    log_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name varchar(100) NOT NULL,
    operation varchar(10) NOT NULL,
    old_data jsonb,
    new_data jsonb,
    db_user varchar(100) NOT NULL DEFAULT session_user,
    changed_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_audit_log_operation CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE'))
);
