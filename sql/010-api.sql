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

CREATE OR REPLACE FUNCTION api.set_log_level(IN p_level api.log_level, IN p_is_local boolean DEFAULT FALSE)
    RETURNS void AS
$$
DECLARE
BEGIN
    PERFORM set_config('app.log_level', p_level::text, p_is_local);
END ;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api.set_log_level(api.log_level, boolean) IS 'Sets the current log level for the application. If p_is_local is true, the setting only applies to the current transaction.';


CREATE OR REPLACE FUNCTION api.log_message(IN p_level api.log_level, IN p_msg text) RETURNS void AS
$$
DECLARE
    v_session_level api.log_level;
BEGIN
    v_session_level = coalesce(current_setting('app.log_level', TRUE), 'INFO')::api.log_level;
    IF p_level <= v_session_level THEN
        RAISE NOTICE '%: %', replace(p_level::text, 'LOG_', ''), p_msg;
    END IF;
END ;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api.log_message(api.log_level, text) IS 'Logs a message at the specified level if the current log level is equal to or higher than the specified level.';

CREATE OR REPLACE FUNCTION api.log_error(IN p_msg text) RETURNS void AS
$$
BEGIN
    PERFORM api.log_message('LOG_ERROR', p_msg);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api.log_error(text) IS 'Convenience function to log a message at ERROR level.';

CREATE OR REPLACE FUNCTION api.log_warning(IN p_msg text) RETURNS void AS
$$
BEGIN
    PERFORM api.log_message('LOG_WARNING', p_msg);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api.log_warning(text) IS 'Convenience function to log a message at WARNING level.';

CREATE OR REPLACE FUNCTION api.log_info(IN p_msg text) RETURNS void AS
$$
BEGIN
    PERFORM api.log_message('INFO'::api.log_level, p_msg);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api.log_info(text) IS 'Convenience function to log a message at INFO level.';

CREATE OR REPLACE FUNCTION api.log_debug(IN p_msg text) RETURNS void AS
$$
BEGIN
    PERFORM api.log_message('LOG_DEBUG', p_msg);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api.log_debug(text) IS 'Convenience function to log a message at DEBUG level.';

CREATE OR REPLACE FUNCTION api.log_trace(IN p_msg text) RETURNS void AS
$$
BEGIN
    PERFORM api.log_message('LOG_TRACE', p_msg);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api.log_trace(text) IS 'Convenience function to log a message at TRACE level (most detailed logging level).';

CREATE OR REPLACE FUNCTION api.raise_exception(IN p_message text,
                                               IN p_severe boolean DEFAULT FALSE,
                                               IN p_info text DEFAULT NULL)
    RETURNS void AS
$$
DECLARE
BEGIN
    IF p_severe THEN
        RAISE EXCEPTION '0B000' USING DETAIL = coalesce(p_message, 'Empty message'), HINT = coalesce(p_info, 'No additional information');
    ELSE
        RAISE EXCEPTION '0A000' USING DETAIL = coalesce(p_message, 'Empty message'), HINT = coalesce(p_info, 'No additional information');
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api.raise_exception(text, boolean, text) IS 'Raises an exception with the specified message and additional information. If p_severe is true, uses error code 0B000, otherwise uses 0A000.';

CREATE OR REPLACE FUNCTION api.raise_exception(IN p_message text,
                                               IN p_severe boolean,
                                               IN p_js_info jsonb)
    RETURNS void AS
$$
DECLARE
BEGIN
    PERFORM api.raise_exception(p_message, p_severe, p_js_info::text);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api.raise_exception(text, boolean, jsonb) IS 'Raises an exception with the specified message and JSONB information. Converts JSONB to text and calls the text version of raise_exception.';

CREATE OR REPLACE FUNCTION api.raise_severe(p_message TEXT,
                                            p_record ANYELEMENT)
    RETURNS VOID AS
$$
SELECT api.raise_exception(p_message, TRUE, TO_JSONB(p_record)::TEXT);
$$ LANGUAGE sql IMMUTABLE;

COMMENT ON FUNCTION api.raise_severe(TEXT, ANYELEMENT) IS 'Raises a severe exception with the specified message and record information. Converts the record to JSONB for detailed error reporting.';

CREATE OR REPLACE FUNCTION api.raise_severe(p_message TEXT)
    RETURNS VOID AS
$$
SELECT api.raise_exception(p_message, TRUE);
$$ LANGUAGE sql IMMUTABLE;

COMMENT ON FUNCTION api.raise_severe(TEXT) IS 'Raises a severe exception with the specified message. Simplified version without additional information.';

CREATE OR REPLACE FUNCTION api.is_null(p_element anyelement)
    RETURNS boolean AS
$$
SELECT (p_element IS NULL);
$$ LANGUAGE sql IMMUTABLE;

COMMENT ON FUNCTION api.is_null(anyelement) IS 'Checks if the provided element is NULL. Returns true if the element is NULL, false otherwise.';

CREATE OR REPLACE FUNCTION api.not_null(p_element anyelement)
    RETURNS boolean AS
$$
SELECT (NOT p_element IS NULL);
$$ LANGUAGE sql IMMUTABLE;

COMMENT ON FUNCTION api.not_null(anyelement) IS 'Checks if the provided element is not NULL. Returns true if the element is not NULL, false otherwise.';

CREATE OR REPLACE FUNCTION api.raise_null(p_element anyelement, p_message text DEFAULT 'Object is null')
    RETURNS void AS
$$
BEGIN
    IF api.is_null(p_element) THEN
        PERFORM api.raise_severe(p_message, p_element);
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION api.raise_null(anyelement, text) IS 'Raises a severe exception if the provided element is NULL. The exception includes the element information for debugging.';
