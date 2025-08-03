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

A complete object persistence layer for database operations with comprehensive CRUD and search capabilities:

#### Core CRUD Operations
- `api_persist.refresh_record(record)`: Refresh a record from the database
- `api_persist.fetch_record(record, id)`: Fetch a record by primary key
- `api_persist.insert_record(record)`: Insert a new record
- `api_persist.delete_record(record)`: Delete a record
- `api_persist.update_record(record)`: Update an existing record
- `api_persist.upsert_record(record)`: Insert or update a record

#### Advanced Search Operations ✨ NEW
- `api_persist.find_record(record, strip_null, check_null, check_unique)`: Flexible search with configurable behavior
- `api_persist.find_single_record(record)`: Find exactly one record (throws error if 0 or multiple found)
- `api_persist.find_many_records(record) RETURNS SETOF`: Find all matching records
- `api_persist.find_optional_record(record)`: Find zero or one record (returns NULL if not found)

The search functions support:
- **Smart type detection**: Automatic handling of booleans, numbers, strings, and NULL values
- **LIKE patterns**: Use `%` wildcards for partial matching
- **Field filtering**: Automatically strips NULL fields from search criteria
- **Flexible error handling**: Configurable behavior for no results or multiple results

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
    v_users record[];
BEGIN
    -- Fetch a user by ID
    v_user := api_persist.fetch_record(NULL::users, '123');
    
    -- Find a user by email (expect exactly one)
    v_user := api_persist.find_single_record(
        jsonb_populate_record(NULL::users, '{"email": "user@example.com"}')
    );
    
    -- Find all users matching criteria
    SELECT array_agg(u) INTO v_users 
    FROM api_persist.find_many_records(
        jsonb_populate_record(NULL::users, '{"status": "active"}')
    ) u;
    
    -- Check if user exists (optional find)
    v_user := api_persist.find_optional_record(
        jsonb_populate_record(NULL::users, '{"username": "john_doe"}')
    );
    IF v_user IS NOT NULL THEN
        RAISE NOTICE 'User found: %', v_user.username;
    END IF;
    
    -- Search with LIKE pattern
    SELECT array_agg(u) INTO v_users
    FROM api_persist.find_many_records(
        jsonb_populate_record(NULL::users, '{"name": "John%"}')
    ) u;
    
    -- Update a user
    v_user.name = 'New Name';
    v_user := api_persist.update_record(v_user);
    
    -- Insert a new user  
    v_user := api_persist.insert_record(
        jsonb_populate_record(NULL::users, '{"name": "New User", "email": "new@example.com"}')
    );
    
    -- Upsert (insert or update)
    v_user := api_persist.upsert_record(v_user);
    
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

## 🚀 Sample Applications

Two comprehensive sample applications demonstrate plpg-api capabilities in different domains:

### 📋 Task Manager (`sample-app/task-manager/`)
A complete project management system showcasing:
- **Database-first design**: All business logic in PL/pgSQL functions
- **Relationship handling**: Tasks, categories, and metadata management
- **JSON operations**: Dynamic metadata storage and manipulation
- **Web APIs**: Both Python (FastAPI) and Node.js (Express) implementations
- **Full CRUD**: Create, read, update, delete operations via persistence layer

### 🏦 Bank Simulator (`sample-app/bank-simulator/`)
A realistic banking system demonstrating:
- **Complex business logic**: Account management, transactions, balance validation
- **Atomic operations**: Database transactions ensure financial consistency  
- **Advanced error handling**: Insufficient funds, account validation, transfer limits
- **Multi-implementation**: Both Python (FastAPI) and Node.js (Express) servers
- **Search capabilities**: Find customers, accounts, and transaction history

Both applications include:
- ✅ Complete database schemas with constraints and relationships
- ✅ Comprehensive API functions using plpg-api patterns  
- ✅ Web server implementations with RESTful endpoints
- ✅ Test suites with example requests (`.rest` files)
- ✅ Detailed setup and usage documentation

### 🎯 Key Demonstrations

- **Database-First Architecture**: Business logic lives in PostgreSQL, web layer is just HTTP translation
- **Type Safety**: Custom PostgreSQL types ensure data integrity
- **Error Handling**: HTTP-like status codes with detailed error messages
- **Dynamic Function Calling**: `api.call()` bridges JSON APIs to typed PL/pgSQL functions
- **Persistence Layer**: Generic CRUD operations with advanced search capabilities
- **Performance**: Prepared statements and connection pooling for production use

### 📋 Quick Start

```bash
# Install core plpg-api framework
psql -f sql/000-ddl.sql
psql -f sql/010-api.sql  
psql -f sql/011-json.sql
psql -f sql/012-throw.sql
psql -f sql/013-call.sql
psql -f sql/020-persistence-internal.sql
psql -f sql/021-persistence-public.sql

# Choose a sample application
cd sample-app/task-manager/    # OR cd sample-app/bank-simulator/
psql -f *.sql                  # Install schema and API functions

# Run web server (Python or Node.js)
python app.py                  # OR npm install && npm start
```

Visit the individual sample app directories for detailed setup instructions and API documentation.

## 📄 License

MIT

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
