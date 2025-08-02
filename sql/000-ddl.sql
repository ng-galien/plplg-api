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

DROP SCHEMA IF EXISTS api CASCADE;
CREATE SCHEMA IF NOT EXISTS api;

CREATE TYPE api.log_level AS enum (
    'ERROR',
    'WARN',
    'INFO',
    'DEBUG',
    'TRACE'
    );

CREATE TYPE api.api_info AS
(
    invalid     boolean,
    reason      text,
    proc_name   text,
    proc_schema text,
    full_args   text,
    json_args   text,
    has_output  boolean,
    payload     jsonb
);


CREATE TYPE api.call_result AS
(
    result_code       integer,
    result_message text,
    result_data          jsonb
);