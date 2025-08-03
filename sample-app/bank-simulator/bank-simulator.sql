-- Bank Simulator Schema for plpg-api
-- A simple banking system demonstrating accounts, customers, and transactions

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
    id          BIGSERIAL PRIMARY KEY,
    customer_id BIGINT NOT NULL REFERENCES bank.customer (id),
    account_number TEXT NOT NULL UNIQUE,
    account_type TEXT NOT NULL DEFAULT 'checking', -- checking, savings
    balance     DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    status      TEXT NOT NULL DEFAULT 'active', -- active, frozen, closed
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp
);

-- Create the transaction table
CREATE TABLE bank.transaction
(
    id             BIGSERIAL PRIMARY KEY,
    from_account_id BIGINT REFERENCES bank.account (id),
    to_account_id   BIGINT REFERENCES bank.account (id),
    transaction_type TEXT NOT NULL, -- deposit, withdrawal, transfer
    amount         DECIMAL(15, 2) NOT NULL,
    description    TEXT,
    created_at     TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    CONSTRAINT valid_transaction_type CHECK (transaction_type IN ('deposit', 'withdrawal', 'transfer')),
    CONSTRAINT valid_amount CHECK (amount > 0),
    CONSTRAINT valid_transfer CHECK (
        (transaction_type = 'transfer' AND from_account_id IS NOT NULL AND to_account_id IS NOT NULL) OR
        (transaction_type = 'deposit' AND from_account_id IS NULL AND to_account_id IS NOT NULL) OR
        (transaction_type = 'withdrawal' AND from_account_id IS NOT NULL AND to_account_id IS NULL)
    )
);

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
    customer_id    BIGINT,
    account_number TEXT,
    account_type   TEXT,
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
    amount              DECIMAL(15, 2),
    description         TEXT
);

-- Generate unique account numbers
CREATE OR REPLACE FUNCTION bank.generate_account_number()
RETURNS TEXT AS
$$
BEGIN
    RETURN 'ACC' || LPAD(nextval('bank.account_id_seq')::TEXT, 10, '0');
END;
$$ LANGUAGE plpgsql;

-- Insert some sample data
INSERT INTO bank.customer (first_name, last_name, email, phone) VALUES
('John', 'Doe', 'john.doe@email.com', '555-0101'),
('Jane', 'Smith', 'jane.smith@email.com', '555-0102'),
('Bob', 'Johnson', 'bob.johnson@email.com', '555-0103');

INSERT INTO bank.account (customer_id, account_number, account_type, balance) VALUES
(1, bank.generate_account_number(), 'checking', 1000.00),
(1, bank.generate_account_number(), 'savings', 5000.00),
(2, bank.generate_account_number(), 'checking', 750.50),
(3, bank.generate_account_number(), 'checking', 2500.00);
