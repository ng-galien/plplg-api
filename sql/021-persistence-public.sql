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

DROP SCHEMA IF EXISTS api_persist CASCADE;
CREATE SCHEMA api_persist;

CREATE OR REPLACE FUNCTION api_persist.refresh_record(
    INOUT p_record anyelement,
    IN p_info jsonb DEFAULT NULL) RETURNS anyelement AS
$$
DECLARE
    v_info      jsonb;
    v_table_id  bigint;
    v_js_record jsonb;
BEGIN
    v_info = coalesce(p_info, api_persist_internal.get_info(p_record));
    PERFORM api.throw_not_null(p_record, 'Record is null');
    v_js_record = to_jsonb(p_record);
    v_table_id = (jsonb_extract_path_text(v_js_record, v_info -> 'primary_key' ->> 'name'))::bigint;
    IF NOT exists(SELECT 1
                  FROM pg_prepared_statements
                  WHERE name = (v_info -> 'select_statement' ->> 'id'))
    THEN
        PERFORM api_persist_internal.deallocate_info(v_info);
        PERFORM api_persist_internal.prepare_info(v_info);
    END IF;

    EXECUTE format('EXECUTE %s(%L)', v_info -> 'select_statement' ->> 'id', v_table_id)
        INTO p_record;

    PERFORM api.throw_not_null(p_record, 'Record is null');
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api_persist.refresh_record(anyelement, jsonb) IS 'Refreshes a record from the database using its primary key. Ensures the record contains the most up-to-date data.';

CREATE OR REPLACE FUNCTION api_persist.fetch_record(
    INOUT p_record anyelement,
    IN p_record_id text,
    IN p_check_null boolean DEFAULT TRUE,
    IN p_cache_info jsonb DEFAULT NULL) RETURNS anyelement AS
$$
DECLARE
    v_info jsonb;
BEGIN
    -- Assume table id is not null
    PERFORM api.throw_not_null(p_record_id, 'Record id is null');
    v_info = coalesce(p_cache_info, api_persist_internal.get_info(p_record));
    IF NOT exists(SELECT 1
                  FROM pg_prepared_statements
                  WHERE name = (v_info -> 'select_statement' ->> 'id'))
    THEN
        PERFORM api_persist_internal.deallocate_info(v_info);
        PERFORM api_persist_internal.prepare_info(v_info);
    END IF;
    EXECUTE format('EXECUTE %s(%L)', v_info -> 'select_statement' ->> 'id', p_record_id)
        INTO p_record;
    IF p_check_null THEN
        PERFORM api.throw_not_null(p_record, 'Record not found for id: ' || p_record_id);
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api_persist.fetch_record(anyelement, text, boolean, jsonb) IS 'Fetches a record from the database by its ID. Can optionally throw an exception if the record is not found.';

CREATE OR REPLACE FUNCTION api_persist.insert_record(
    INOUT p_record anyelement,
    IN p_check_null boolean DEFAULT TRUE,
    IN p_cache_info jsonb DEFAULT NULL,
    IN p_preserve_id boolean DEFAULT FALSE) RETURNS anyelement AS
$$
DECLARE
    v_info     jsonb;
    v_table_id text;
BEGIN
    v_info = coalesce(p_cache_info, api_persist_internal.get_info(p_record));
    EXECUTE api_persist_internal.get_insert_statement(p_record := p_record,
                                                      p_check_null := p_check_null,
                                                      p_info := v_info,
                                                      p_preserve_id := p_preserve_id)::text INTO v_table_id;
    p_record = api_persist.fetch_record(p_record := p_record, p_record_id := v_table_id, p_cache_info := v_info);
END
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api_persist.insert_record(anyelement, boolean, jsonb, boolean) IS 'Inserts a record into the database and returns the newly created record with its assigned ID. Can optionally preserve an existing ID.';

CREATE OR REPLACE FUNCTION api_persist.delete_record(
    INOUT p_record anyelement,
    IN p_cache_info jsonb DEFAULT NULL) RETURNS anyelement AS
$$
DECLARE
    v_info      jsonb;
    v_record_id bigint;
BEGIN
    v_info = coalesce(p_cache_info, api_persist_internal.get_info(p_record));
    PERFORM api.throw_not_null(p_record, 'Record is null');
    v_record_id = (jsonb_extract_path_text(to_jsonb(p_record), (v_info -> 'primary_key' ->> 'name')))::bigint;
    -- Execute update
    IF NOT exists(SELECT 1
                  FROM pg_prepared_statements
                  WHERE name = (v_info -> 'delete_statement' ->> 'id'))
    THEN
        PERFORM api_persist_internal.deallocate_info(v_info);
        PERFORM api_persist_internal.prepare_info(v_info);
    END IF;

    EXECUTE format('EXECUTE %s(%L)', v_info -> 'delete_statement' ->> 'id', v_record_id);

END
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api_persist.delete_record(anyelement, jsonb) IS 'Deletes a record from the database using its primary key. Returns the deleted record.';

CREATE OR REPLACE FUNCTION api_persist.update_record(
    INOUT p_record anyelement,
    IN p_check_null boolean DEFAULT TRUE,
    IN p_cache_info jsonb DEFAULT NULL) RETURNS anyelement AS
$$
DECLARE
    v_info      jsonb;
    v_statement text;
BEGIN

    v_info = coalesce(p_cache_info, api_persist_internal.get_info(p_record));

    v_statement = api_persist_internal.get_update_statement(
            p_record := p_record, p_check_null := p_check_null, p_cache_info := v_info
                  );

    IF v_statement IS NOT NULL THEN
        EXECUTE v_statement;
        p_record = api_persist.refresh_record(p_record := p_record, p_info := v_info);
    END IF;

END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api_persist.update_record(anyelement, boolean, jsonb) IS 'Updates a record in the database and refreshes it to get the latest data. Can optionally check for NULL values in non-nullable columns.';

CREATE OR REPLACE FUNCTION api_persist.upsert_record(
    INOUT p_record anyelement,
    IN p_info jsonb DEFAULT NULL) RETURNS anyelement AS
$$
DECLARE
    v_info     jsonb;
    v_table_id text;
BEGIN
    v_info = coalesce(p_info, api_persist_internal.get_info(p_record));
    PERFORM api.throw_not_null(v_info, 'Cache info is null');
    v_table_id = (jsonb_extract_path_text(to_jsonb(p_record), (v_info -> 'primary_key' ->> 'name')))::text;
    IF v_table_id IS NULL THEN
        p_record = api_persist.insert_record(p_record := p_record, p_cache_info := v_info);
    ELSE
        p_record = api_persist.update_record(p_record := p_record, p_cache_info := v_info);
    END IF;
END ;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api_persist.upsert_record(anyelement, jsonb) IS 'Inserts a new record if it doesn''t exist (no primary key) or updates it if it does exist. Provides a convenient way to save records without knowing their state.';