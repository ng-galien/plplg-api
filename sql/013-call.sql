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

--Main entry point for the API, takes a function name and a variable number of arguments,
CREATE OR REPLACE FUNCTION api.call(p_function TEXT, p_arg jsonb)
    RETURNS api.call_result AS
$$
DECLARE
    v_result          api.call_result;
    v_function        TEXT;
    v_schema          TEXT;
    v_return_many     BOOLEAN;
    v_nb_args         INT;
    v_arg_type_id     OID;
    v_arg_type_name   TEXT;
    v_query           TEXT;
    v_err_code text;
    v_ex_detail text;
    v_ex_hint text;
    v_ex_context text;
BEGIN
    -- Check if the function exists
    PERFORM api.throw_not_null(p_function, 'Function name cannot be null');
    -- Resolve the function name with the schema
    IF position('.' IN p_function) > 0 THEN
        v_schema = (string_to_array(p_function, '.'))[1];
        v_function = (string_to_array(p_function, '.'))[2];
    ELSE
        v_schema = 'public';
        v_function = p_function;
    END IF;
    SELECT proretset, (proargtypes::oid[])[0], pronargs
    FROM pg_catalog.pg_proc
    WHERE proname = v_function
      AND pronamespace = (SELECT oid FROM pg_catalog.pg_namespace WHERE nspname = v_schema)
      AND prokind = 'f'
    AND pronargs <= 1
    INTO v_return_many, v_arg_type_id, v_nb_args;
    IF NOT found THEN
        PERFORM api.throw_error('Routine ' || v_schema || '.' || v_function || ' does not exist');
    END IF;
    --Get the argument type name
    SELECT n.nspname || '.' || t.typname
    INTO v_arg_type_name
    FROM pg_catalog.pg_type t
             JOIN pg_catalog.pg_namespace n ON t.typnamespace = n.oid
    WHERE t.oid = v_arg_type_id;

    IF v_return_many THEN
        v_query = 'SELECT jsonb_agg(call) FROM ' || v_schema || '.' || v_function;
    ELSE
        v_query = 'SELECT to_jsonb(call) FROM ' || v_schema || '.' || v_function;
    END IF;
    IF v_nb_args = 0 THEN
        v_query = v_query || '() call';
    ELSIF v_arg_type_name = 'pg_catalog.jsonb' THEN
        -- If the argument type is cstring, we can pass it directly as a string
        v_query = v_query || '($1) call';
    ELSE
        v_query = v_query || '(jsonb_populate_record(NULL::' || v_arg_type_name || ', $1)) call';
    END IF;
    -- Debug
    RAISE NOTICE 'Query with signature: %', v_query;
    -- Execute the function with the provided argument
    EXECUTE v_query INTO v_result.result_data USING p_arg;
    v_result.result_code = 200;
    v_result.result_message = 'Routine ' || v_schema || '.' || v_function || ' executed successfully with arguments: ' || p_arg;
    RETURN v_result;
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_code = MESSAGE_TEXT,
            v_ex_detail = PG_EXCEPTION_DETAIL,
            v_ex_hint = PG_EXCEPTION_HINT,
            v_ex_context = PG_EXCEPTION_CONTEXT;
        RAISE NOTICE 'Error code: %, Detail: %, Hint: %, Context: %', v_err_code, v_ex_detail, v_ex_hint, v_ex_context;
        v_result.result_message := v_ex_detail;
        CASE v_err_code
            WHEN 'P0400' THEN
                v_result.result_code = 400;
                v_result.result_message := coalesce(v_result.result_message, 'Bad request');
            WHEN 'P0401' THEN
                v_result.result_code = 401;
                v_result.result_message := coalesce(v_result.result_message, 'Unauthorized');
            WHEN 'P0402' THEN
                v_result.result_code = 402;
                v_result.result_message := coalesce(v_result.result_message, 'Payment required');
            WHEN 'P0403' THEN
                v_result.result_code = 403;
                v_result.result_message := coalesce(v_result.result_message, 'Forbidden');
            WHEN 'P0404' THEN
                v_result.result_code = 404;
                v_result.result_message := coalesce(v_result.result_message, 'Not found');
            WHEN 'P0405' THEN
                v_result.result_code = 405;
                v_result.result_message := coalesce(v_result.result_message, 'Method not allowed');
            WHEN 'P0406' THEN
                v_result.result_code = 406;
                v_result.result_message := coalesce(v_result.result_message, 'Not acceptable');
            WHEN 'P0407' THEN
                v_result.result_code = 407;
                v_result.result_message := coalesce(v_result.result_message, 'Proxy authentication required');
            WHEN 'P0408' THEN
                v_result.result_code = 408;
                v_result.result_message := coalesce(v_result.result_message, 'Request timeout');
            WHEN 'P0409' THEN
                v_result.result_code = 409;
                v_result.result_message := coalesce(v_result.result_message, 'Conflict');
            WHEN 'P0410' THEN
                v_result.result_code = 410;
                v_result.result_message := coalesce(v_result.result_message, 'Gone');
            WHEN 'P0411' THEN
                v_result.result_code = 411;
                v_result.result_message := coalesce(v_result.result_message, 'Length required');
            WHEN 'P0412' THEN
                v_result.result_code = 412;
                v_result.result_message := coalesce(v_result.result_message, 'Precondition failed');
            WHEN 'P0413' THEN
                v_result.result_code = 413;
                v_result.result_message := coalesce(v_result.result_message, 'Payload too large');
            WHEN 'P0414' THEN
                v_result.result_code = 414;
                v_result.result_message := coalesce(v_result.result_message, 'URI too long');
            WHEN 'P0415' THEN
                v_result.result_code = 415;
                v_result.result_message := coalesce(v_result.result_message, 'Unsupported media type');
            WHEN 'P0416' THEN
                v_result.result_code = 416;
                v_result.result_message := coalesce(v_result.result_message, 'Range not satisfiable');
            WHEN 'P0417' THEN
                v_result.result_code = 417;
                v_result.result_message := coalesce(v_result.result_message, 'Expectation failed');
            ELSE
                v_result.result_code = 500;
                v_result.result_message := coalesce(v_result.result_message, 'Internal server error');
        END CASE;
        RETURN v_result;
END
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api.call(TEXT, jsonb) IS 'Main entry point for dynamically calling functions with JSON arguments. Returns a standardized result with HTTP-like status codes for success and error handling.';
