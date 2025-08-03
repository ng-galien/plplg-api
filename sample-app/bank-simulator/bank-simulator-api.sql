-- Bank Simulator API Functions for plpg-api
-- This file contains the API functions for the bank simulator

SELECT api.set_log_level('DEBUG');

-- Verify that the bank schema exists
DO
$$
    BEGIN
        IF NOT exists (SELECT 1 FROM pg_tables WHERE schemaname = 'bank' AND tablename = 'customer') THEN
            RAISE EXCEPTION 'The bank.customer table does not exist. Please run bank-simulator.sql first.';
        END IF;

        IF NOT exists (SELECT 1 FROM pg_tables WHERE schemaname = 'bank' AND tablename = 'account') THEN
            RAISE EXCEPTION 'The bank.account table does not exist. Please run bank-simulator.sql first.';
        END IF;

        IF NOT exists (SELECT 1 FROM pg_tables WHERE schemaname = 'bank' AND tablename = 'transaction') THEN
            RAISE EXCEPTION 'The bank.transaction table does not exist. Please run bank-simulator.sql first.';
        END IF;
    END
$$;

-- Customer Functions

CREATE OR REPLACE FUNCTION bank.get_all_customers()
    RETURNS SETOF bank.customer AS
$$
BEGIN
    RETURN QUERY SELECT * FROM bank.customer ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bank.get_customer(p_customer_id bank.customer_id_type)
    RETURNS bank.customer AS
$$
BEGIN
    RETURN api_persist.fetch_record(NULL::bank.customer, p_customer_id.id::TEXT, TRUE);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bank.create_customer(p_create bank.customer_create_type)
    RETURNS bank.customer AS
$$
BEGIN
    RETURN api_persist.insert_record(
            jsonb_populate_record(NULL::bank.customer, to_jsonb(p_create))
           );
END;
$$ LANGUAGE plpgsql;

-- Account Functions

CREATE OR REPLACE FUNCTION bank.get_customer_accounts(p_customer_id bank.customer_id_type)
    RETURNS SETOF bank.account AS
$$
BEGIN
    RETURN QUERY 
    SELECT * FROM bank.account 
    WHERE customer_id = p_customer_id.id 
    ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bank.get_account_by_number(p_account_number bank.account_number_type)
    RETURNS jsonb AS
$$
DECLARE
    v_account bank.account;
    v_customer bank.customer;
BEGIN
    SELECT * INTO v_account 
    FROM bank.account 
    WHERE account_number = p_account_number.account_number;
    
    IF NOT FOUND THEN
        PERFORM api.throw_not_found('Account not found');
    END IF;
    
    SELECT * INTO v_customer 
    FROM bank.customer 
    WHERE id = v_account.customer_id;
    
    RETURN to_jsonb(v_account) || jsonb_build_object(
        'customer', to_jsonb(v_customer)
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bank.create_account(p_create bank.account_create_type)
    RETURNS bank.account AS
$$
DECLARE
    v_account bank.account;
    v_account_number TEXT;
BEGIN
    -- Generate account number if not provided
    v_account_number := COALESCE(p_create.account_number, bank.generate_account_number());
    
    -- Create the account record
    v_account := api_persist.insert_record(
        jsonb_populate_record(
            NULL::bank.account, 
            to_jsonb(p_create) || jsonb_build_object(
                'account_number', v_account_number,
                'balance', COALESCE(p_create.initial_balance, 0.00)
            )
        )
    );
    
    RETURN v_account;
END;
$$ LANGUAGE plpgsql;

-- Transaction Functions

CREATE OR REPLACE FUNCTION bank.deposit(p_deposit bank.transaction_deposit_type)
    RETURNS jsonb AS
$$
DECLARE
    v_account bank.account;
    v_transaction bank.transaction;
BEGIN
    -- Get the account
    SELECT * INTO v_account 
    FROM bank.account 
    WHERE account_number = p_deposit.account_number AND status = 'active';
    
    IF NOT FOUND THEN
        PERFORM api.throw_not_found('Active account not found');
    END IF;
    
    -- Validate amount
    IF p_deposit.amount <= 0 THEN
        PERFORM api.throw_error('Deposit amount must be positive');
    END IF;
    
    -- Update account balance
    UPDATE bank.account 
    SET balance = balance + p_deposit.amount,
        updated_at = current_timestamp
    WHERE id = v_account.id;
    
    -- Create transaction record
    INSERT INTO bank.transaction (to_account_id, transaction_type, amount, description)
    VALUES (v_account.id, 'deposit', p_deposit.amount, p_deposit.description)
    RETURNING * INTO v_transaction;
    
    -- Return updated account info with transaction
    SELECT * INTO v_account FROM bank.account WHERE id = v_account.id;
    
    RETURN jsonb_build_object(
        'transaction', to_jsonb(v_transaction),
        'account', to_jsonb(v_account),
        'message', 'Deposit successful'
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bank.withdraw(p_withdrawal bank.transaction_withdrawal_type)
    RETURNS jsonb AS
$$
DECLARE
    v_account bank.account;
    v_transaction bank.transaction;
BEGIN
    -- Get the account
    SELECT * INTO v_account 
    FROM bank.account 
    WHERE account_number = p_withdrawal.account_number AND status = 'active';
    
    IF NOT FOUND THEN
        PERFORM api.throw_not_found('Active account not found');
    END IF;
    
    -- Validate amount
    IF p_withdrawal.amount <= 0 THEN
        PERFORM api.throw_error('Withdrawal amount must be positive');
    END IF;
    
    -- Check sufficient funds
    IF v_account.balance < p_withdrawal.amount THEN
        PERFORM api.throw_error('Insufficient funds');
    END IF;
    
    -- Update account balance
    UPDATE bank.account 
    SET balance = balance - p_withdrawal.amount,
        updated_at = current_timestamp
    WHERE id = v_account.id;
    
    -- Create transaction record
    INSERT INTO bank.transaction (from_account_id, transaction_type, amount, description)
    VALUES (v_account.id, 'withdrawal', p_withdrawal.amount, p_withdrawal.description)
    RETURNING * INTO v_transaction;
    
    -- Return updated account info with transaction
    SELECT * INTO v_account FROM bank.account WHERE id = v_account.id;
    
    RETURN jsonb_build_object(
        'transaction', to_jsonb(v_transaction),
        'account', to_jsonb(v_account),
        'message', 'Withdrawal successful'
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bank.transfer(p_transfer bank.transaction_transfer_type)
    RETURNS jsonb AS
$$
DECLARE
    v_from_account bank.account;
    v_to_account bank.account;
    v_transaction bank.transaction;
BEGIN
    -- Get the from account
    SELECT * INTO v_from_account 
    FROM bank.account 
    WHERE account_number = p_transfer.from_account_number AND status = 'active';
    
    IF NOT FOUND THEN
        PERFORM api.throw_not_found('Source account not found or inactive');
    END IF;
    
    -- Get the to account
    SELECT * INTO v_to_account 
    FROM bank.account 
    WHERE account_number = p_transfer.to_account_number AND status = 'active';
    
    IF NOT FOUND THEN
        PERFORM api.throw_not_found('Destination account not found or inactive');
    END IF;
    
    -- Validate amount
    IF p_transfer.amount <= 0 THEN
        PERFORM api.throw_error('Transfer amount must be positive');
    END IF;
    
    -- Check sufficient funds
    IF v_from_account.balance < p_transfer.amount THEN
        PERFORM api.throw_error('Insufficient funds');
    END IF;
    
    -- Update account balances
    UPDATE bank.account 
    SET balance = balance - p_transfer.amount,
        updated_at = current_timestamp
    WHERE id = v_from_account.id;
    
    UPDATE bank.account 
    SET balance = balance + p_transfer.amount,
        updated_at = current_timestamp
    WHERE id = v_to_account.id;
    
    -- Create transaction record
    INSERT INTO bank.transaction (from_account_id, to_account_id, transaction_type, amount, description)
    VALUES (v_from_account.id, v_to_account.id, 'transfer', p_transfer.amount, p_transfer.description)
    RETURNING * INTO v_transaction;
    
    -- Return transaction info with updated accounts
    SELECT * INTO v_from_account FROM bank.account WHERE id = v_from_account.id;
    SELECT * INTO v_to_account FROM bank.account WHERE id = v_to_account.id;
    
    RETURN jsonb_build_object(
        'transaction', to_jsonb(v_transaction),
        'from_account', to_jsonb(v_from_account),
        'to_account', to_jsonb(v_to_account),
        'message', 'Transfer successful'
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bank.get_account_transactions(p_account_number bank.account_number_type)
    RETURNS SETOF bank.transaction AS
$$
DECLARE
    v_account_id BIGINT;
BEGIN
    -- Get account ID
    SELECT id INTO v_account_id 
    FROM bank.account 
    WHERE account_number = p_account_number.account_number;
    
    IF NOT FOUND THEN
        PERFORM api.throw_not_found('Account not found');
    END IF;
    
    RETURN QUERY 
    SELECT * FROM bank.transaction 
    WHERE from_account_id = v_account_id OR to_account_id = v_account_id
    ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql;
