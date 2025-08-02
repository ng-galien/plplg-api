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

CREATE SCHEMA IF NOT EXISTS json_util;

CREATE OR REPLACE FUNCTION json_util.is_valid(p_json TEXT)
    RETURNS BOOLEAN
AS
$$
BEGIN
    IF p_json IS NULL THEN
        RETURN TRUE;
    END IF;
    RETURN (p_json::JSONB IS NOT NULL);
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION json_util.is_valid(TEXT) IS 'Checks if the provided text is a valid JSON string. Returns true if the string is NULL or can be cast to JSONB, false otherwise.';

CREATE OR REPLACE FUNCTION json_util.clean_attributes(p_js JSONB, attributes TEXT[])
    RETURNS JSONB AS
$$
DECLARE
    result JSONB;
    v      RECORD;
BEGIN
    result = p_js;
    FOR v IN SELECT * FROM JSONB_EACH(p_js) LOOP
            IF NOT v.key = ANY (attributes) THEN
                result = result - v.key;
            END IF;
        END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION json_util.clean_attributes(JSONB, TEXT[]) IS 'Removes all attributes from a JSONB object that are not in the specified array of attribute names.';

CREATE OR REPLACE FUNCTION json_util.diff(p_new JSONB, p_old JSONB)
    RETURNS JSONB AS
$$
DECLARE
    result JSONB;
    v      RECORD;
BEGIN
    result = p_new;
    FOR v IN SELECT * FROM JSONB_EACH(p_old) LOOP
            IF result @> JSONB_BUILD_OBJECT(v.key, v.value) THEN
                IF JSONB_TYPEOF(v.value) = 'object' THEN
                    IF (result -> v.key)::TEXT LIKE v.value::TEXT THEN
                        result = result - v.key;
                    END IF;
                ELSE
                    result = result - v.key;
                END IF;

            ELSIF result ? v.key THEN
                CONTINUE;
            ELSE
                result = result || JSONB_BUILD_OBJECT(v.key, NULL);
            END IF;
        END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION json_util.diff(JSONB, JSONB) IS 'Calculates the difference between two JSONB objects. Returns a JSONB object containing only the keys that differ between the two input objects.';

CREATE OR REPLACE FUNCTION json_util.extract_keys_if_exists(p_jsonb jsonb, p_keys text[]) RETURNS jsonb AS
$$
SELECT coalesce(jsonb_object_agg(key, value), '{}'::jsonb)
FROM jsonb_each($1)
WHERE key = ANY ($2);
$$ LANGUAGE SQL
    IMMUTABLE
    STRICT;
    
COMMENT ON FUNCTION json_util.extract_keys_if_exists(jsonb, text[]) IS 'Extracts only the specified keys from a JSONB object if they exist. Returns a new JSONB object containing only those keys.';

CREATE OR REPLACE FUNCTION json_util.is_null(p_json jsonb, p_key text) RETURNS boolean AS
$$
SELECT jsonb_extract_path_text(p_json, p_key) IS NULL;
$$ LANGUAGE sql IMMUTABLE
                PARALLEL SAFE;
                
COMMENT ON FUNCTION json_util.is_null(jsonb, text) IS 'Checks if a specific key in a JSONB object is NULL or does not exist. Returns true if the key is NULL or missing.';

CREATE OR REPLACE FUNCTION json_util.is_not_null(p_json jsonb, p_key text) RETURNS boolean AS
$$
SELECT jsonb_extract_path_text(p_json, p_key) IS NOT NULL;
$$ LANGUAGE sql IMMUTABLE
                PARALLEL SAFE;
                
COMMENT ON FUNCTION json_util.is_not_null(jsonb, text) IS 'Checks if a specific key in a JSONB object exists and is not NULL. Returns true if the key exists and has a non-NULL value.';

--Check if a jsonb does not contain a array of keys or if the value of a key is null
CREATE OR REPLACE FUNCTION json_util.are_null(p_json jsonb, p_keys text[]) RETURNS boolean AS
$$
SELECT exists(SELECT 1 FROM unnest(p_keys) AS p_key WHERE json_util.is_null(p_json, p_key));
$$ LANGUAGE sql IMMUTABLE
                PARALLEL SAFE;
                
COMMENT ON FUNCTION json_util.are_null(jsonb, text[]) IS 'Checks if any of the specified keys in a JSONB object are NULL or missing. Returns true if at least one key is NULL or missing.';

CREATE OR REPLACE FUNCTION json_util.clean_attributes(p_js JSONB, attributes TEXT[])
    RETURNS JSONB AS
$$
DECLARE
    result JSONB;
    v      RECORD;
BEGIN
    result = p_js;
    FOR v IN SELECT * FROM JSONB_EACH(p_js) LOOP
            IF NOT v.key = ANY (attributes) THEN
                result = result - v.key;
            END IF;
        END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION json_util.clean_attributes(JSONB, TEXT[]) IS 'Removes all attributes from a JSONB object that are not in the specified array of attribute names. This is a duplicate function definition.';
