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

CREATE OR REPLACE FUNCTION api.throw_error(p_message text DEFAULT 'An error occurred')
    RETURNS void AS
$$
BEGIN
    RAISE EXCEPTION 'P0500' USING DETAIL = coalesce(p_message, 'An error occurred'), HINT = 'No additional information';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION api.throw_error(text) IS 'Throws a general error with HTTP status code 500 equivalent. Uses error code P0500.';

CREATE OR REPLACE FUNCTION api.throw_not_null(p_element anyelement, p_message text DEFAULT 'Object is null')
    RETURNS void AS
$$
BEGIN
    IF api.is_null(p_element) THEN
        RAISE EXCEPTION 'P0500' USING DETAIL = coalesce(p_message, 'Object is null'), HINT = 'No additional information';
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION api.throw_not_null(anyelement, text) IS 'Throws an error if the provided element is NULL. Uses error code P0500 (HTTP 500 equivalent).';

CREATE OR REPLACE FUNCTION api.throw_invalid(p_message text DEFAULT 'Invalid argument')
    RETURNS void AS
$$
BEGIN
    RAISE EXCEPTION 'P0400' USING DETAIL = coalesce(p_message, 'Invalid argument'), HINT = 'No additional information';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION api.throw_invalid(text) IS 'Throws an invalid argument error with HTTP status code 400 equivalent. Uses error code P0400.';

CREATE OR REPLACE FUNCTION api.throw_forbidden(p_message text DEFAULT 'Forbidden')
    RETURNS void AS
$$
BEGIN
    RAISE EXCEPTION 'P0403' USING DETAIL = coalesce(p_message, 'Forbidden'), HINT = 'No additional information';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION api.throw_forbidden(text) IS 'Throws a forbidden access error with HTTP status code 403 equivalent. Uses error code P0403.';

CREATE OR REPLACE FUNCTION api.throw_not_found(p_message text DEFAULT 'Not found')
    RETURNS void AS
$$
BEGIN
    RAISE EXCEPTION 'P0404' USING DETAIL = coalesce(p_message, 'Not found'), HINT = 'No additional information';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION api.throw_not_found(text) IS 'Throws a not found error with HTTP status code 404 equivalent. Uses error code P0404.';