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
    INOUT p_record ANYELEMENT,
    IN p_info jsonb DEFAULT NULL) RETURNS ANYELEMENT AS
$$
DECLARE
    v_info      jsonb;
    v_table_id  BIGINT;
    v_js_record jsonb;
BEGIN
    v_info = coalesce(p_info, api_persist_internal.get_info(p_record));
    PERFORM api.throw_not_null(p_record, 'Record is null');
    v_js_record = to_jsonb(p_record);
    v_table_id = (jsonb_extract_path_text(v_js_record, v_info -> 'primary_key' ->> 'name'))::BIGINT;
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

COMMENT ON FUNCTION api_persist.refresh_record(ANYELEMENT, jsonb) IS 'Refreshes a record from the database using its primary key. Ensures the record contains the most up-to-date data.';

CREATE OR REPLACE FUNCTION api_persist.fetch_record(
    INOUT p_record ANYELEMENT,
    IN p_record_id TEXT,
    IN p_check_null BOOLEAN DEFAULT TRUE,
    IN p_cache_info jsonb DEFAULT NULL) RETURNS ANYELEMENT AS
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

COMMENT ON FUNCTION api_persist.fetch_record(ANYELEMENT, TEXT, BOOLEAN, jsonb) IS 'Fetches a record from the database by its ID. Can optionally throw an exception if the record is not found.';

CREATE OR REPLACE FUNCTION api_persist.insert_record(
    INOUT p_record ANYELEMENT,
    IN p_check_null BOOLEAN DEFAULT TRUE,
    IN p_cache_info jsonb DEFAULT NULL,
    IN p_preserve_id BOOLEAN DEFAULT FALSE) RETURNS ANYELEMENT AS
$$
DECLARE
    v_info     jsonb;
    v_table_id TEXT;
BEGIN
    v_info = coalesce(p_cache_info, api_persist_internal.get_info(p_record));
    EXECUTE api_persist_internal.get_insert_statement(p_record := p_record,
                                                      p_check_null := p_check_null,
                                                      p_info := v_info,
                                                      p_preserve_id := p_preserve_id)::TEXT INTO v_table_id;
    p_record = api_persist.fetch_record(p_record := p_record, p_record_id := v_table_id, p_cache_info := v_info);
END
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api_persist.insert_record(ANYELEMENT, BOOLEAN, jsonb, BOOLEAN) IS 'Inserts a record into the database and returns the newly created record with its assigned ID. Can optionally preserve an existing ID.';

CREATE OR REPLACE FUNCTION api_persist.delete_record(
    INOUT p_record ANYELEMENT,
    IN p_cache_info jsonb DEFAULT NULL) RETURNS ANYELEMENT AS
$$
DECLARE
    v_info      jsonb;
    v_record_id BIGINT;
BEGIN
    v_info = coalesce(p_cache_info, api_persist_internal.get_info(p_record));
    PERFORM api.throw_not_null(p_record, 'Record is null');
    v_record_id = (jsonb_extract_path_text(to_jsonb(p_record), (v_info -> 'primary_key' ->> 'name')))::BIGINT;
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

COMMENT ON FUNCTION api_persist.delete_record(ANYELEMENT, jsonb) IS 'Deletes a record from the database using its primary key. Returns the deleted record.';

CREATE OR REPLACE FUNCTION api_persist.update_record(
    INOUT p_record ANYELEMENT,
    IN p_check_null BOOLEAN DEFAULT TRUE,
    IN p_cache_info jsonb DEFAULT NULL) RETURNS ANYELEMENT AS
$$
DECLARE
    v_info      jsonb;
    v_statement TEXT;
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

COMMENT ON FUNCTION api_persist.update_record(ANYELEMENT, BOOLEAN, jsonb) IS 'Updates a record in the database and refreshes it to get the latest data. Can optionally check for NULL values in non-nullable columns.';

CREATE OR REPLACE FUNCTION api_persist.upsert_record(
    INOUT p_record ANYELEMENT,
    IN p_info jsonb DEFAULT NULL) RETURNS ANYELEMENT AS
$$
DECLARE
    v_info     jsonb;
    v_table_id TEXT;
BEGIN
    v_info = coalesce(p_info, api_persist_internal.get_info(p_record));
    PERFORM api.throw_not_null(v_info, 'Cache info is null');
    v_table_id = (jsonb_extract_path_text(to_jsonb(p_record), (v_info -> 'primary_key' ->> 'name')))::TEXT;
    IF v_table_id IS NULL THEN
        p_record = api_persist.insert_record(p_record := p_record, p_cache_info := v_info);
    ELSE
        p_record = api_persist.update_record(p_record := p_record, p_cache_info := v_info);
    END IF;
END ;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api_persist.upsert_record(ANYELEMENT, jsonb) IS 'Inserts a new record if it doesn''t exist (no primary key) or updates it if it does exist. Provides a convenient way to save records without knowing their state.';

CREATE OR REPLACE FUNCTION api_persist.find_record(INOUT p_record ANYELEMENT,
                                                   IN p_strip_null BOOLEAN DEFAULT TRUE,
                                                   IN p_check_null BOOLEAN DEFAULT TRUE,
                                                   IN p_check_unique BOOLEAN DEFAULT TRUE,
                                                   IN p_cache_info jsonb DEFAULT NULL) RETURNS ANYELEMENT AS
$$
DECLARE
    v_record_info jsonb;
    v_record      jsonb;
    v_js_clean    jsonb;
    v_count       INT;
    v_where       TEXT;
    v_schema_name TEXT;
    v_table_name  TEXT;
    v_primary_key TEXT;
    v_query       TEXT;
BEGIN
    RAISE NOTICE 'Finding record with parameters: %', p_record;
    v_record_info = coalesce(p_cache_info, api_persist_internal.get_info(p_record));
    v_schema_name = v_record_info ->> 'schema_name';
    v_table_name = v_record_info ->> 'table_name';
    v_primary_key = v_record_info -> 'primary_key' ->> 'name';
    IF p_record IS NULL THEN
        PERFORM api.throw_error('find_record => ' || v_schema_name || '.' || v_table_name || ' Record cannot be null');
    END IF;
    v_record = to_jsonb(p_record);
    v_js_clean = json_util.clean_attributes(v_record,
                                            (SELECT array_agg(name)
                                             FROM jsonb_to_recordset(v_record_info -> 'columns') AS x(name TEXT)));
    IF p_strip_null THEN
        v_js_clean = jsonb_strip_nulls(v_js_clean);
    END IF;
    SELECT string_agg(CASE
                          WHEN value::TEXT = ANY (ARRAY ['true','false'])
                              THEN concat(key, ' IS ', value #>> '{}')
                          WHEN value::TEXT = 'null'
                              THEN concat(key, ' IS NULL')
                          WHEN regexp_match(value::TEXT, '^-?[0-9]*\.{0,1}[0-9]+$') IS NOT NULL
                              THEN concat(key, ' = ', value #>> '{}')
                          WHEN position('%' IN value::TEXT) > 0
                              THEN concat(key, ' LIKE ', format('%L', value #>> '{}'))
                          ELSE
                              concat(key, ' = ', format('%L', value #>> '{}'))
                          END, ' AND ')
    FROM jsonb_each(v_js_clean)
    INTO v_where;

    IF v_where IS NULL THEN
        IF p_check_null THEN
            PERFORM api.throw_not_found('find_record => ' || v_schema_name || '.' || v_table_name || ' WHERE clause empty with search criteria: ' || coalesce(v_js_clean::TEXT, 'null'));
        ELSE
            RETURN;
        END IF;
    END IF;
    v_query = format('SELECT COUNT(*) FROM %I.%I WHERE %s',
                     (v_record_info ->> 'schema_name'),
                     (v_record_info ->> 'table_name'),
                     v_where);
    RAISE NOTICE 'Executing query: %', v_query;
    EXECUTE v_query INTO v_count;
    CASE
        WHEN v_count = 1 THEN EXECUTE format('SELECT * FROM %I.%I WHERE %s',
                                             (v_record_info ->> 'schema_name'),
                                             (v_record_info ->> 'table_name'),
                                             v_where) INTO p_record;
        WHEN v_count > 1 THEN IF p_check_unique THEN
            PERFORM api.throw_invalid('find_record => Too many records found');
        ELSE
            PERFORM api.log_warning('Too many records found, taking the first row');
            EXECUTE format('SELECT * FROM %I.%I WHERE %s LIMIT 1',
                           (v_record_info ->> 'schema_name'),
                           (v_record_info ->> 'table_name'),
                           v_where) INTO p_record;
        END IF;
        ELSE IF p_check_null THEN
            PERFORM api.throw_not_found('find_record => ' || v_schema_name || '.' || v_table_name || ' No record found with search criteria: ' || coalesce(v_js_clean::TEXT, 'null'));
             END IF;
             EXECUTE format('SELECT NULL::%I.%I',
                            (v_record_info ->> 'schema_name'),
                            (v_record_info ->> 'table_name')) INTO p_record;
        END CASE;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api_persist.find_record(ANYELEMENT, BOOLEAN, BOOLEAN, BOOLEAN, jsonb) IS 'Finds a record by matching non-null fields in the input record. Supports flexible search patterns including LIKE operations (use % wildcards). Parameters: p_strip_null removes null fields from search, p_check_null throws error if no record found, p_check_unique throws error if multiple records found.';

CREATE OR REPLACE FUNCTION api_persist.find_single_record(INOUT p_record ANYELEMENT,
                                                          IN p_strip_null BOOLEAN DEFAULT TRUE,
                                                          IN p_cache_info jsonb DEFAULT NULL) RETURNS ANYELEMENT AS
$$
BEGIN
    -- Call find_record with strict single-record requirements
    p_record = api_persist.find_record(
            p_record := p_record,
            p_strip_null := p_strip_null,
            p_check_null := TRUE, -- Always throw error if no record found
            p_check_unique := TRUE, -- Always throw error if multiple records found
            p_cache_info := p_cache_info
               );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api_persist.find_single_record(ANYELEMENT, BOOLEAN, jsonb) IS 'Finds exactly one record by matching non-null fields. Throws error if no record found or if multiple records match the criteria. Use for scenarios where you expect exactly one result.';

CREATE OR REPLACE FUNCTION api_persist.find_many_records(IN p_record ANYELEMENT,
                                                         IN p_strip_null BOOLEAN DEFAULT TRUE,
                                                         IN p_cache_info jsonb DEFAULT NULL) RETURNS SETOF ANYELEMENT AS
$$
DECLARE
    v_record_info jsonb;
    v_record      jsonb;
    v_js_clean    jsonb;
    v_where       TEXT;
    v_query       TEXT;
BEGIN
    v_record_info = coalesce(p_cache_info, api_persist_internal.get_info(p_record));

    IF p_record IS NULL THEN
        PERFORM api.raise_exception('Record cannot be null', TRUE);
    END IF;

    v_record = to_jsonb(p_record);
    v_js_clean = json_util.clean_attributes(v_record,
                                            (SELECT array_agg(name)
                                             FROM jsonb_to_recordset(v_record_info -> 'columns') AS x(name TEXT)));
    IF p_strip_null THEN
        v_js_clean = jsonb_strip_nulls(v_js_clean);
    END IF;

    -- Build WHERE clause using same logic as find_record
    SELECT string_agg(CASE
                          WHEN value::TEXT = ANY (ARRAY ['true','false'])
                              THEN concat(key, ' IS ', value #>> '{}')
                          WHEN value::TEXT = 'null'
                              THEN concat(key, ' IS NULL')
                          WHEN regexp_match(value::TEXT, '^-?[0-9]*\.{0,1}[0-9]+$') IS NOT NULL
                              THEN concat(key, ' = ', value #>> '{}')
                          WHEN position('%' IN value::TEXT) > 0
                              THEN concat(key, ' LIKE ', format('%L', value #>> '{}'))
                          ELSE
                              concat(key, ' = ', format('%L', value #>> '{}'))
                          END, ' AND ')
    FROM jsonb_each(v_js_clean)
    INTO v_where;

    -- Build and execute query
    v_query = format('SELECT * FROM %I.%I',
                     (v_record_info ->> 'schema_name'),
                     (v_record_info ->> 'table_name'));

    IF v_where IS NOT NULL THEN
        v_query = v_query || ' WHERE ' || v_where;
    END IF;

    RETURN QUERY EXECUTE v_query;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api_persist.find_many_records(ANYELEMENT, BOOLEAN, jsonb) IS 'Finds all records matching the non-null fields in the input record. Returns a set of matching records. If no search criteria provided (all fields null), returns all records from the table.';

CREATE OR REPLACE FUNCTION api_persist.find_optional_record(INOUT p_record ANYELEMENT,
                                                            IN p_strip_null BOOLEAN DEFAULT TRUE,
                                                            IN p_cache_info jsonb DEFAULT NULL) RETURNS ANYELEMENT AS
$$
BEGIN
    -- Call find_record with lenient requirements - allows no results, but ensures uniqueness
    p_record = api_persist.find_record(
            p_record := p_record,
            p_strip_null := p_strip_null,
            p_check_null := FALSE, -- Don't throw error if no record found
            p_check_unique := TRUE, -- Still throw error if multiple records found
            p_cache_info := p_cache_info
               );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api_persist.find_optional_record(ANYELEMENT, BOOLEAN, jsonb) IS 'Finds zero or one record by matching non-null fields. Returns NULL if no record found, throws error if multiple records match. Use when a record may or may not exist.';
