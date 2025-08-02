# 🚀 plplg-api

A collection of useful PL/pgSQL functions for PostgreSQL database development.

## 📋 Overview

plplg-api provides a set of utility functions and modules to simplify PostgreSQL database development. It leverages PostgreSQL's powerful capabilities to handle application logic directly in the database, making it ideal for POC (Proof of Concept), demos, and simple CRUD applications without the hassle of a boilerplate middleware. The library includes:

- 📝 Logging utilities with configurable log levels
- ⚠️ Error handling with HTTP-like status codes
- 🔄 JSON manipulation utilities
- 💾 Object persistence layer for CRUD operations
- 📞 Dynamic function calling with JSON arguments

## 📥 Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/plplg-api.git
   cd plplg-api
   ```

2. Execute the SQL files in the correct order:
   ```sql
   \i sql/000-ddl.sql
   \i sql/010-api.sql
   \i sql/011-json.sql
   \i sql/012-throw.sql
   \i sql/013-call.sql
   \i sql/020-persistence-internal.sql
   \i sql/021-persistence-public.sql
   ```

## 🧩 Modules

### 🛠️ Core API (010-api.sql)

Provides basic logging and error handling functions:

- `api.set_log_level(level)`: Set the current logging level
- `api.log_message(level, message)`: Log a message at the specified level
- `api.log_error/warning/info/debug/trace(message)`: Convenience functions for logging
- `api.raise_exception(message, severe, info)`: Raise an exception with detailed information
- `api.raise_severe(message)`: Raise a severe exception
- `api.is_null/not_null(element)`: Check if an element is null or not
- `api.raise_null(element, message)`: Raise an exception if the element is null

### 🔄 JSON Utilities (011-json.sql)

Functions for working with JSON data:

- `json_util.is_valid(json)`: Check if a JSON string is valid
- `json_util.clean_attributes(js, attributes)`: Remove attributes not in the specified list
- `json_util.diff(new, old)`: Get the difference between two JSON objects
- `json_util.extract_keys_if_exists(jsonb, keys)`: Extract specified keys from a JSON object
- `json_util.is_null/is_not_null(json, key)`: Check if a JSON key is null or not
- `json_util.are_null(json, keys)`: Check if any of the specified keys are null

### ⚠️ Error Handling (012-throw.sql)

Functions for throwing specific types of errors:

- `api.throw_error(message)`: Throw a general error
- `api.throw_not_null(element, message)`: Throw an error if the element is null
- `api.throw_invalid(message)`: Throw an invalid argument error
- `api.throw_forbidden(message)`: Throw a forbidden access error
- `api.throw_not_found(message)`: Throw a not found error

### 📞 Dynamic Function Calling (013-call.sql)

Function for dynamically calling other functions with JSON arguments:

- `api.call(function_name, args)`: Call a function with JSON arguments and get a standardized result

Important notes about the call function:
- It's designed to inject JSON from web APIs and convert it to typed records in PL/pgSQL code
- You cannot define multiple functions with the same name but different argument signatures (the system will only recognize the first matching function)
- The function only supports functions with 0 or 1 arguments
- Returns standardized results with HTTP-like status codes for success and error handling

### 💾 Persistence Layer (020-persistence-internal.sql, 021-persistence-public.sql)

A complete object persistence layer for database operations:

- `api_persist.refresh_record(record)`: Refresh a record from the database
- `api_persist.fetch_record(record, id)`: Fetch a record by ID
- `api_persist.insert_record(record)`: Insert a new record
- `api_persist.delete_record(record)`: Delete a record
- `api_persist.update_record(record)`: Update an existing record
- `api_persist.upsert_record(record)`: Insert or update a record

## 📚 Usage Examples

### 📝 Logging

```sql
-- Set the log level
SELECT api.set_log_level('INFO');

-- Log messages at different levels
SELECT api.log_info('This is an info message');
SELECT api.log_debug('This is a debug message'); -- Won't be displayed if log level is INFO
```

### ⚠️ Error Handling

```sql
-- Throw a not found error
SELECT api.throw_not_found('User with ID 123 not found');

-- Check for null values
SELECT api.throw_not_null(some_variable, 'Variable cannot be null');
```

### 💾 Persistence Layer

```sql
-- Example of using the persistence layer in a function
CREATE OR REPLACE FUNCTION example_persistence_usage()
RETURNS void AS $$
DECLARE
    v_user record;
BEGIN
    -- Fetch a user by ID
    SELECT * INTO v_user FROM users WHERE id = 123;
    v_user := api_persist.fetch_record(v_user, 123);
    
    -- Update a user
    UPDATE users SET name = 'New Name' WHERE id = v_user.id;
    v_user := api_persist.update_record(v_user);
    
    -- Insert a new user
    INSERT INTO users (name, email) VALUES ('New User', 'user@example.com') RETURNING * INTO v_user;
    v_user := api_persist.insert_record(v_user);
    
    -- Delete a user
    v_user := api_persist.delete_record(v_user);
END;
$$ LANGUAGE plpgsql;
```

### 📞 Dynamic Function Calling

```sql
-- Call a function with JSON arguments
SELECT * FROM api.call('my_schema.get_user', '{"id": 123}'::jsonb);

-- Handle the result
DO $$
DECLARE
    v_result api.call_result;
BEGIN
    v_result = api.call('my_schema.get_user', '{"id": 123}'::jsonb);
    
    IF v_result.result_code = 200 THEN
        -- Success
        RAISE NOTICE 'User: %', v_result.result_data;
    ELSE
        -- Error
        RAISE NOTICE 'Error %: %', v_result.result_code, v_result.result_message;
    END IF;
END $$;
```

## 🚀 Sample Application

A task management demo app is included to showcase plplg-api capabilities:

- Database schema with relationships
- CRUD operations via the persistence layer
- Error handling with HTTP status codes
- JSON data manipulation
- Dynamic function calling

### 📋 Demo App Structure & Usage

The demo consists of three files:
- `sample-app/task-manager.sql` - Schema and initial data
- `sample-app/task-manager-api.sql` - API functions
- `sample-app/task-manager-demo.sql` - Usage examples

Run the demo with:

```sql
-- Install core files
\i sql/000-ddl.sql
\i sql/010-api.sql
\i sql/011-json.sql
\i sql/012-throw.sql
\i sql/013-call.sql
\i sql/020-persistence-internal.sql
\i sql/021-persistence-public.sql

-- Run demo
\i sample-app/task-manager.sql
\i sample-app/task-manager-api.sql
\i sample-app/task-manager-demo.sql
```

The demo demonstrates task management, category handling, JSON operations, and proper error handling - all using PostgreSQL's native capabilities.

## 📄 License

MIT

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.