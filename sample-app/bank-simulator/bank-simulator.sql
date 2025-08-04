-- Bank Simulator Schema for plpg-api
-- A simple banking system demonstrating accounts, customers, and transactions
DROP SCHEMA IF EXISTS bank CASCADE;
-- Create the bank schema
CREATE SCHEMA IF NOT EXISTS bank;

-- Create the customer table
CREATE TABLE bank.customer
(
    id         BIGSERIAL PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name  TEXT NOT NULL,
    email      TEXT NOT NULL UNIQUE,
    phone      TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp
);

-- Create the account table
CREATE TABLE bank.account
(
    id             BIGSERIAL PRIMARY KEY,
    customer_id    BIGINT         NOT NULL REFERENCES bank.customer (id),
    account_number TEXT           NOT NULL UNIQUE,
    account_type   TEXT           NOT NULL  DEFAULT 'checking', -- checking, savings
    CONSTRAINT valid_account_type CHECK (account_type IN ('checking', 'savings', 'credit')),
    balance        DECIMAL(15, 2) NOT NULL  DEFAULT 0.00,
    authorized_overdraft DECIMAL(15, 2) DEFAULT 0.00, -- for credit accounts
    CONSTRAINT valid_authorized_overdraft CHECK (authorized_overdraft >= 0),
    CONSTRAINT valid_balance CHECK (balance  + authorized_overdraft >= 0),
    status         TEXT           NOT NULL  DEFAULT 'active',   -- active, frozen, closed
    CONSTRAINT valid_status CHECK (status IN ('active', 'frozen', 'closed')),
    created_at     TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    updated_at     TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp
);

-- Create the transaction table
CREATE TABLE bank.transaction
(
    id               BIGSERIAL PRIMARY KEY,
    from_account_id  BIGINT REFERENCES bank.account (id),
    to_account_id    BIGINT REFERENCES bank.account (id),
    transaction_type TEXT           NOT NULL, -- deposit, withdrawal, transfer
    CONSTRAINT valid_transaction_type CHECK (transaction_type IN ('deposit', 'withdrawal', 'transfer')),
    transaction_status TEXT NOT NULL DEFAULT 'pending', -- pending, completed, failed
    CONSTRAINT valid_transaction_status CHECK (transaction_status IN ('pending', 'completed', 'failed')),
    amount           DECIMAL(15, 2) NOT NULL,
    CONSTRAINT valid_amount CHECK (amount > 0),
    description      TEXT,
    created_at       TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    CONSTRAINT valid_transfer CHECK (
        (transaction_type = 'transfer' AND from_account_id IS NOT NULL AND to_account_id IS NOT NULL) OR
        (transaction_type = 'deposit' AND from_account_id IS NULL AND to_account_id IS NOT NULL) OR
        (transaction_type = 'withdrawal' AND from_account_id IS NOT NULL AND to_account_id IS NULL)
        )
);

-- Trigger to update the account's balance after a transaction
CREATE OR REPLACE FUNCTION bank.update_account_balance()
    RETURNS TRIGGER AS
$$
BEGIN
    IF new.transaction_type = 'deposit' THEN
        UPDATE bank.account
        SET balance    = balance + new.amount,
            updated_at = current_timestamp
        WHERE id = new.to_account_id;
    ELSIF new.transaction_type = 'withdrawal' THEN
        UPDATE bank.account
        SET balance    = balance - new.amount,
            updated_at = current_timestamp
        WHERE id = new.from_account_id;
    ELSIF new.transaction_type = 'transfer' THEN
        UPDATE bank.account
        SET balance    = balance - new.amount,
            updated_at = current_timestamp
        WHERE id = new.from_account_id;

        UPDATE bank.account
        SET balance    = balance + new.amount,
            updated_at = current_timestamp
        WHERE id = new.to_account_id;
    END IF;
    RETURN new;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bank.delete_transaction_is_forbidden()
    RETURNS TRIGGER AS
$$
BEGIN
    -- Prevent deletion of all transactions
    PERFORM api.throw_forbidden('Deletion of transactions is not allowed');
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_account_balance
    AFTER INSERT OR UPDATE
    ON bank.transaction
    FOR EACH ROW
    WHEN ( new.transaction_status = 'completed' )
EXECUTE FUNCTION bank.update_account_balance();

CREATE TRIGGER trg_delete_transaction_is_forbidden
    BEFORE DELETE
    ON bank.transaction
    FOR EACH ROW
EXECUTE FUNCTION bank.delete_transaction_is_forbidden();

-- Type Definitions for Bank API

-- Customer types
DROP TYPE IF EXISTS bank.customer_id_type CASCADE;
CREATE TYPE bank.customer_id_type AS
(
    id BIGINT
);

DROP TYPE IF EXISTS bank.customer_create_type CASCADE;
CREATE TYPE bank.customer_create_type AS
(
    first_name TEXT,
    last_name  TEXT,
    email      TEXT,
    phone      TEXT
);

DROP TYPE IF EXISTS bank.customer_update_type CASCADE;
CREATE TYPE bank.customer_update_type AS
(
    id         BIGINT,
    first_name TEXT,
    last_name  TEXT,
    email      TEXT,
    phone      TEXT
);

-- Account types
DROP TYPE IF EXISTS bank.account_id_type CASCADE;
CREATE TYPE bank.account_id_type AS
(
    id BIGINT
);

DROP TYPE IF EXISTS bank.account_create_type CASCADE;
CREATE TYPE bank.account_create_type AS
(
    customer_id     BIGINT,
    account_number  TEXT,
    account_type    TEXT,
    initial_balance DECIMAL(15, 2)
);

DROP TYPE IF EXISTS bank.account_number_type CASCADE;
CREATE TYPE bank.account_number_type AS
(
    account_number TEXT
);

-- Transaction types
DROP TYPE IF EXISTS bank.transaction_deposit_type CASCADE;
CREATE TYPE bank.transaction_deposit_type AS
(
    account_number TEXT,
    amount         DECIMAL(15, 2),
    description    TEXT
);

DROP TYPE IF EXISTS bank.transaction_withdrawal_type CASCADE;
CREATE TYPE bank.transaction_withdrawal_type AS
(
    account_number TEXT,
    amount         DECIMAL(15, 2),
    description    TEXT
);

DROP TYPE IF EXISTS bank.transaction_transfer_type CASCADE;
CREATE TYPE bank.transaction_transfer_type AS
(
    from_account_number TEXT,
    to_account_number   TEXT,
    status              TEXT,
    amount              DECIMAL(15, 2),
    description         TEXT
);

DROP TYPE IF EXISTS bank.transaction_cancel_type CASCADE;
CREATE TYPE bank.transaction_cancel_type AS
(
    transaction_id BIGINT,
    reason         TEXT
);



-- Generate unique account numbers
CREATE OR REPLACE FUNCTION bank.generate_account_number()
    RETURNS TEXT AS
$$
BEGIN
    RETURN 'ACC' || lpad(nextval('bank.account_id_seq')::TEXT, 10, '0');
END;
$$ LANGUAGE plpgsql;

-- Insert some sample data
INSERT INTO bank.customer (first_name, last_name, email, phone)
VALUES ('John', 'Doe', 'john.doe@email.com', '555-0101'),
       ('Jane', 'Smith', 'jane.smith@email.com', '555-0102'),
       ('Bob', 'Johnson', 'bob.johnson@email.com', '555-0103');

INSERT INTO bank.account (customer_id, account_number, account_type, balance)
VALUES (1, bank.generate_account_number(), 'checking', 1000.00),
       (1, bank.generate_account_number(), 'savings', 5000.00),
       (2, bank.generate_account_number(), 'checking', 750.50),
       (3, bank.generate_account_number(), 'checking', 2500.00);
