-- MIT License
--
-- Copyright (c) 2025 plplg-api Contributors
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE users
(
    id         SERIAL PRIMARY KEY,
    username   VARCHAR(50)  NOT NULL UNIQUE,
    password   VARCHAR(255) NOT NULL,
    email      VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT current_timestamp,
    updated_at TIMESTAMP DEFAULT current_timestamp
);

CREATE TABLE roles
(
    uuid        uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

INSERT INTO users (username, password, email)
VALUES ('testuser', 'password123', 'test@mail.com');

SELECT *
FROM api_persist.fetch_record(NULL::users, 1::TEXT, FALSE);

SELECT *
FROM api_persist.insert_record((NULL, 'testuser2', 'password456', 'test3@mail.com', NULL, NULL)::users, TRUE, NULL,
                               FALSE);

SELECT *
FROM api_persist.refresh_record((4, NULL, NULL, NULL, NULL, NULL)::users, NULL);

SELECT *
FROM api_persist.update_record((2, 'updateduser123', 'newpassword', 'test2@mail.com', NULL, NULL)::users, TRUE, NULL);

CREATE OR REPLACE FUNCTION all_users()
    RETURNS SETOF users AS
$$
BEGIN
    RETURN QUERY SELECT * FROM users;
END;
$$ LANGUAGE plpgsql;

CREATE TYPE arg_type AS
(
    text_val TEXT,
    int_val  INT
);

CREATE TYPE res_type AS
(
    text_val TEXT,
    int_val  INT
);

CREATE OR REPLACE FUNCTION my_function(IN p_arg arg_type)
    RETURNS res_type AS
$$
DECLARE
    v_result res_type;
BEGIN
    v_result.text_val := 'Hello, ' || p_arg.text_val;
    v_result.int_val := p_arg.int_val * 2;
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION my_void_function(IN p_arg arg_type)
    RETURNS VOID AS
$$
BEGIN
    RAISE NOTICE 'Processing argument: %, %', p_arg.text_val, p_arg.int_val;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION my_multi_function(IN p_arg arg_type)
    RETURNS SETOF res_type AS
$$
DECLARE
    v_result res_type;
BEGIN
    v_result.text_val := 'Hello, ' || p_arg.text_val;
    v_result.int_val := p_arg.int_val * 2;
    RETURN NEXT v_result;
    v_result.text_val := 'Goodbye, ' || p_arg.text_val;
    v_result.int_val := p_arg.int_val + 10;
    RETURN NEXT v_result;
    RETURN;
END;
$$ LANGUAGE plpgsql;

SELECT to_jsonb(call) FROM my_function(('World', 5)::arg_type) call;

SELECT to_jsonb(call) FROM my_void_function(('Test', 10)::arg_type) call;

SELECT jsonb_agg(call) FROM my_multi_function(('Multi', 3)::arg_type) call;

SELECT jsonb_agg(call) FROM all_users() call;

SELECT proname, (proargtypes::oid[])[0], proretset FROM pg_proc
WHERE proname = 'my_function' OR proname = 'my_void_function' OR proname = 'my_multi_function' OR proname = 'all_users';

SELECT * FROM api.call('my_function', '{"text_val": "World", "int_val": 5}'::jsonb);
SELECT * FROM api.call('my_multi_function', '{"text_val": "Multi", "int_val": 3}'::jsonb);
SELECT * FROM api.call(NULL, '{"text_val": "World", "int_val": 5}'::jsonb);

SELECT proname, proretset, (proargtypes::oid[])[0], pronargs
FROM pg_catalog.pg_proc
WHERE proname = 'my_function'
  AND pronamespace = (SELECT oid FROM pg_catalog.pg_namespace WHERE nspname ='public')
  AND prokind = 'f';