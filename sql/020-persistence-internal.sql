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

DROP SCHEMA IF EXISTS api_persist_internal CASCADE;
CREATE SCHEMA IF NOT EXISTS api_persist_internal;

CREATE TABLE IF NOT EXISTS api_persist_internal.reference
(
    id         bigserial PRIMARY KEY,
    identifier oid   NOT NULL UNIQUE,
    info       jsonb NOT NULL
);

--Trigger function that truncate the reference table
-- DROP FUNCTION IF EXISTS api_persist_internal.clean_cache();
CREATE OR REPLACE FUNCTION api_persist_internal.clean_cache() RETURNS EVENT_TRIGGER AS
$$
BEGIN
    --Here we must not use TRUNCATE because it will not call the trigger for prepared statements
    DELETE FROM api_persist_internal.reference WHERE TRUE;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api_persist_internal.clean_cache() IS 'Event trigger function that cleans the reference cache table when tables are created, altered, or dropped.';

--Event trigger on DDl commands that DROP, CREATE, or ALTER a table
CREATE EVENT TRIGGER clean_cache
    ON ddl_command_end
    WHEN TAG IN ('DROP TABLE', 'CREATE TABLE', 'ALTER TABLE')
EXECUTE PROCEDURE api_persist_internal.clean_cache();

CREATE OR REPLACE FUNCTION api_persist_internal.get_oid(IN p_record ANYELEMENT) RETURNS OID
AS
$$
SELECT ((PG_TYPEOF(p_record))::TEXT)::REGCLASS::OID;
$$ LANGUAGE sql;

COMMENT ON FUNCTION api_persist_internal.get_oid(ANYELEMENT) IS 'Gets the OID (object identifier) of the table that the record belongs to.';

CREATE OR REPLACE FUNCTION api_persist_internal.create_info(
    IN p_oid OID,
    IN p_discard_primary_key BOOLEAN DEFAULT FALSE) RETURNS JSONB AS
$$
DECLARE
    v_oid              INT4;
    v_table_name       TEXT;
    v_schema_name      TEXT;
    v_js_result        JSONB;
    v_primary_key_name TEXT;
BEGIN
    SELECT t_class.oid, t_namespace.nspname, t_class.relname
    FROM pg_class t_class
             JOIN pg_namespace t_namespace ON t_class.relnamespace = t_namespace.oid
    WHERE t_class.oid = p_oid-- ((PG_TYPEOF(p_record))::TEXT)::REGCLASS::OID
      AND t_class.relkind IN ('r', 'p', 'f')
    INTO v_oid, v_schema_name, v_table_name;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Element is not a table %', p_oid::TEXT;
    END IF;

    v_js_result = JSONB_BUILD_OBJECT(
            'oid', v_oid,
            'schema_name', v_schema_name,
            'table_name', v_table_name,
            'primary_key', (SELECT JSONB_BUILD_OBJECT('name', t_attribute.attname,
                                                      'sequence',
                                                      (PG_GET_SERIAL_SEQUENCE(v_schema_name || '.' || v_table_name,
                                                                              t_attribute.attname)))
                            FROM pg_class t_class
                                     JOIN pg_attribute t_attribute ON t_attribute.attrelid = t_class.oid
                                     JOIN pg_constraint t_contraint
                                          ON t_contraint.conrelid = t_class.oid
                                              AND t_contraint.contype = 'p'
                                              AND
                                             t_attribute.attnum = ANY (t_contraint.conkey)

                            WHERE t_class.oid = v_oid
                              AND t_attribute.attnum > 0
                              AND t_attribute.atttypid > 0),
            'columns', (SELECT ARRAY_AGG(
                                       JSONB_BUILD_OBJECT(
                                               'name', t_attribute.attname,
                                               'nullable', NOT t_attribute.attnotnull,
                                               'has_default', t_attribute.atthasdef,
                                               'foreign_key', (SELECT t_contraint.confrelid::BIGINT
                                                               FROM pg_constraint t_contraint
                                                               WHERE t_contraint.conrelid = t_class.oid
                                                                 AND t_contraint.contype = 'f'
                                                                 AND t_attribute.attnum = ANY (t_contraint.conkey)
                                                               LIMIT 1)
                                       ))
                        FROM pg_class t_class
                                 JOIN pg_attribute t_attribute ON t_attribute.attrelid = t_class.oid

                        WHERE t_class.oid = v_oid
                          AND t_attribute.attnum > 0
                          AND t_attribute.atttypid > 0
            )
                  );


    IF NOT p_discard_primary_key AND
       (json_util.is_null(v_js_result, 'primary_key')
           OR json_util.is_null(COALESCE(v_js_result -> 'primary_key', '{}'::JSONB), 'sequence')) THEN
        RAISE EXCEPTION 'Invalid primary key for %', p_oid::TEXT;
    END IF;

    IF json_util.is_null(v_js_result, 'primary_key') THEN
        v_primary_key_name = '';
    ELSE
        v_primary_key_name = v_js_result -> 'primary_key' ->> 'name';
    END IF;

    v_js_result = v_js_result || JSONB_BUILD_OBJECT('select_statement',
                                                    JSONB_BUILD_OBJECT('id', 'select_' || v_oid,
                                                                       'query',
                                                                       FORMAT('SELECT * FROM %I.%I WHERE %I=$1',
                                                                              v_js_result ->> 'schema_name',
                                                                              v_js_result ->> 'table_name',
                                                                              v_primary_key_name
                                                                       )
                                                    ),
                                                    'delete_statement',
                                                    JSONB_BUILD_OBJECT('id', 'delete_' || v_oid,
                                                                       'query',
                                                                       FORMAT('DELETE FROM %I.%I WHERE %I=$1',
                                                                              v_js_result ->> 'schema_name',
                                                                              v_js_result ->> 'table_name',
                                                                              v_primary_key_name
                                                                       )
                                                    )
                                 );

    RETURN v_js_result;
END
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api_persist_internal.create_info(OID, BOOLEAN) IS 'Creates a JSONB object containing metadata about a table, including its schema, name, primary key, columns, and prepared statement definitions.';

-- This function is used to create a record definition for a table
CREATE OR REPLACE FUNCTION api_persist_internal.create_info(
    IN p_record ANYELEMENT) RETURNS JSONB AS
$$
SELECT api_persist_internal.create_info(api_persist_internal.get_oid(p_record));
$$ LANGUAGE sql;

COMMENT ON FUNCTION api_persist_internal.create_info(ANYELEMENT) IS 'Convenience wrapper that creates a JSONB object containing metadata about a record''s table by extracting the OID from the record.';

CREATE OR REPLACE FUNCTION api_persist_internal.prepare_info(p_info JSONB) RETURNS VOID AS
$$
DECLARE
    v_statement_name TEXT;
BEGIN

    FOR v_statement_name IN SELECT UNNEST(ARRAY ['select_statement', 'delete_statement']) LOOP
            IF NOT EXISTS(SELECT 1
                          FROM pg_prepared_statements
                          WHERE name = JSONB_EXTRACT_PATH_TEXT(p_info, v_statement_name, 'id'))
            THEN
                EXECUTE FORMAT('PREPARE %s(BIGINT) AS %s',
                               JSONB_EXTRACT_PATH_TEXT(p_info, v_statement_name, 'id'),
                               JSONB_EXTRACT_PATH_TEXT(p_info, v_statement_name, 'query'));
            END IF;

        END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api_persist_internal.prepare_info(JSONB) IS 'Prepares SQL statements for select and delete operations based on the provided table metadata JSONB.';

CREATE OR REPLACE FUNCTION api_persist_internal.get_info(
    IN p_record ANYELEMENT) RETURNS JSONB AS
$$
DECLARE
    v_js_info JSONB;
BEGIN
    -- Get cached definition of the table
    SELECT t_reference.info
    FROM api_persist_internal.reference t_reference
    WHERE t_reference.identifier = ((PG_TYPEOF(p_record))::TEXT)::REGCLASS::OID
    LIMIT 1
    INTO v_js_info;

    IF FOUND THEN
        RETURN v_js_info;
    END IF;

    -- Not found, insert into cache table
    v_js_info = api_persist_internal.create_info(p_record);

    IF v_js_info IS NULL THEN
        RAISE EXCEPTION 'No table definition for %', (PG_TYPEOF(p_record))::TEXT;
    END IF;
    PERFORM api_persist_internal.prepare_info(v_js_info);

    INSERT INTO api_persist_internal.reference(identifier, info)
    VALUES ((v_js_info ->> 'oid')::OID,
            v_js_info);

    RETURN v_js_info;
END
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api_persist_internal.get_info(ANYELEMENT) IS 'Gets or creates metadata information for a record''s table. Uses a cache table to avoid repeated metadata extraction.';

CREATE OR REPLACE FUNCTION api_persist_internal.deallocate_info(p_info JSONB) RETURNS VOID AS
$$
DECLARE
    v_statement_name TEXT;
BEGIN
    FOR v_statement_name IN SELECT UNNEST(ARRAY ['select_statement', 'delete_statement']) LOOP
            IF EXISTS(SELECT 1
                      FROM pg_prepared_statements
                      WHERE name = JSONB_EXTRACT_PATH_TEXT(p_info, v_statement_name, 'id'))
            THEN
                EXECUTE FORMAT('DEALLOCATE %s',
                               JSONB_EXTRACT_PATH_TEXT(p_info, v_statement_name, 'id'));
            END IF;

        END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api_persist_internal.deallocate_info(JSONB) IS 'Deallocates prepared SQL statements that were created for a table''s metadata.';

CREATE OR REPLACE FUNCTION api_persist_internal.definition_trigger() RETURNS TRIGGER
AS
$$
BEGIN
    IF tg_op = 'INSERT' AND new.info IS NOT NULL THEN
        PERFORM api_persist_internal.prepare_info(new.info);
        RETURN new;
    ELSIF tg_op = 'DELETE' AND old.info IS NOT NULL THEN
        PERFORM api_persist_internal.deallocate_info(old.info);
        RETURN old;
    END IF;

END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api_persist_internal.definition_trigger() IS 'Trigger function that prepares or deallocates SQL statements when records are inserted or deleted from the reference table.';

CREATE TRIGGER after_trigger
    BEFORE DELETE OR INSERT
    ON api_persist_internal.reference
    FOR EACH ROW
EXECUTE PROCEDURE api_persist_internal.definition_trigger();

CREATE OR REPLACE FUNCTION api_persist_internal.get_insert_statement(IN p_record ANYELEMENT,
                                                                     IN p_check_null BOOLEAN,
                                                                     IN p_info JSONB,
                                                                     IN p_preserve_id BOOLEAN) RETURNS TEXT AS
$$
DECLARE
    v_merge    JSONB;
    v_values   TEXT ARRAY;
    v_inserts  TEXT ARRAY;
    v_col_info RECORD;
BEGIN
    IF p_record IS NULL THEN
        PERFORM api.raise_exception('Record and JSONB both nulls');
    END IF;
    v_merge = TO_JSONB(p_record);
    FOR v_col_info IN SELECT diff.key, diff.value, def.nullable, def.has_default
                      FROM JSONB_EACH(v_merge) diff
                               JOIN JSONB_TO_RECORDSET(p_info -> 'columns') AS def(name TEXT, nullable BOOLEAN, has_default BOOLEAN)
                                    ON diff.key = def.name
        LOOP
            -- Skip primary key
            CONTINUE WHEN NOT p_preserve_id AND v_col_info.key LIKE (p_info -> 'primary_key' ->> 'name');

            IF NOT json_util.is_null(v_merge, v_col_info.key) THEN
                v_values = ARRAY_APPEND(v_values, QUOTE_LITERAL(JSONB_EXTRACT_PATH_TEXT(v_merge, v_col_info.key)));
                v_inserts = ARRAY_APPEND(v_inserts, FORMAT('%I', v_col_info.key));
            ELSIF p_check_null
                AND v_col_info.nullable IS FALSE
                AND v_col_info.has_default IS FALSE THEN
                PERFORM api.raise_exception((p_info ->> 'schema_name') || '.' || (p_info ->> 'table_name')
                                                || '::' || v_col_info.key::TEXT || ' must not be NULL');
            END IF;
        END LOOP;
    IF v_inserts IS NULL THEN
        PERFORM api.raise_exception('Nothing to insert');
    END IF;
    RETURN FORMAT('INSERT INTO %I.%I(%s) VALUES(%s) RETURNING %I',
                  (p_info ->> 'schema_name'),
                  (p_info ->> 'table_name'),
                  ARRAY_TO_STRING(v_inserts, ','),
                  ARRAY_TO_STRING(v_values, ','),
                  (p_info -> 'primary_key' ->> 'name'));
END ;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION api_persist_internal.get_insert_statement(ANYELEMENT, BOOLEAN, JSONB, BOOLEAN) IS 'Generates an INSERT SQL statement for a record based on its table metadata. Can optionally preserve the primary key value and check for NULL values.';

CREATE OR REPLACE FUNCTION api_persist_internal.get_diff(
    IN p_record ANYELEMENT,
    IN p_js JSONB,
    IN p_cache_info JSONB DEFAULT NULL) RETURNS JSONB AS
$$
DECLARE
    v_js_new JSONB;
    v_js_old JSONB;
    v_info   JSONB;
BEGIN
    v_info = COALESCE(p_cache_info, api_persist_internal.get_info(p_record));
    v_js_old = TO_JSONB(p_record);
    v_js_new =json_util.clean_attributes(p_js, (SELECT ARRAY_AGG(name)
                                               FROM JSONB_TO_RECORDSET(v_info -> 'columns') AS x(name TEXT)));
    v_js_new = v_js_old || v_js_new;
    RETURN json_util.diff(v_js_new, v_js_old);
END
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api_persist_internal.get_diff(ANYELEMENT, JSONB, JSONB) IS 'Calculates the difference between a record and a JSONB object. Used to determine what fields have changed for update operations.';

CREATE OR REPLACE FUNCTION api_persist_internal.get_update_statement(
    IN p_record ANYELEMENT,
    IN p_check_null BOOLEAN,
    IN p_cache_info JSONB) RETURNS TEXT AS
$$
DECLARE
    v_js_new   JSONB;
    v_js_diff  JSONB;
    v_values   TEXT ARRAY;
    v_updates  TEXT ARRAY;
    v_col_info RECORD;
    v_table_id text;
BEGIN
    IF p_record IS NULL THEN
        PERFORM api.raise_exception('Record and JSONB both nulls');
    END IF;
    v_js_new = TO_JSONB(p_record);
    v_table_id = (JSONB_EXTRACT_PATH_TEXT(v_js_new, p_cache_info -> 'primary_key' ->> 'name'))::text;
    v_js_diff = v_js_new - (p_cache_info -> 'primary_key' ->> 'name');
    FOR v_col_info IN SELECT diff.*, info.nullable
                      FROM JSONB_EACH(v_js_diff) diff
                               JOIN JSONB_TO_RECORDSET(p_cache_info -> 'columns') AS info(name TEXT, nullable BOOLEAN)
                                    ON diff.key = info.name
        LOOP
            IF JSONB_TYPEOF(v_col_info.value) = 'null' THEN
                IF p_check_null AND NOT v_col_info.nullable THEN
                    PERFORM api.raise_exception(v_col_info.key || ' Must not be NULL');
                END IF;
                v_values = ARRAY_APPEND(v_values, 'NULL');
            ELSE
                v_values = ARRAY_APPEND(v_values, QUOTE_LITERAL(JSONB_EXTRACT_PATH_TEXT(v_js_diff, v_col_info.key)));
            END IF;
            v_updates = ARRAY_APPEND(v_updates, FORMAT('%I', v_col_info.key));
        END LOOP;
    IF v_updates IS NOT NULL THEN
        RETURN FORMAT('UPDATE %I.%I SET (%s) = ROW (%s) WHERE %I = %s',
                      (p_cache_info ->> 'schema_name'),
                      (p_cache_info ->> 'table_name'),
                      ARRAY_TO_STRING(v_updates, ','),
                      ARRAY_TO_STRING(v_values, ','),
                      (p_cache_info -> 'primary_key' ->> 'name'),
                      v_table_id);
    ELSE
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION api_persist_internal.get_update_statement(ANYELEMENT, BOOLEAN, JSONB) IS 'Generates an UPDATE SQL statement for a record based on its table metadata. Can optionally check for NULL values in non-nullable columns.';
