# plpg-api AI Coding Guidelines

## Architecture Overview

This is a PostgreSQL-based API framework that moves application logic into the database using PL/pgSQL. The core philosophy is **database-first development** where business logic lives in stored procedures rather than middleware.

### Key Components

- **Core API Layer** (`sql/010-api.sql`): Logging, error handling, and HTTP-like status codes
- **Dynamic Function Calling** (`sql/013-call.sql`): The `api.call()` function bridges JSON APIs to typed PL/pgSQL functions
- **Persistence Layer** (`sql/020-*.sql`): Generic CRUD operations for any table via `api_persist.*` functions
- **JSON Utilities** (`sql/011-json.sql`): JSON manipulation and validation helpers

## Critical Installation Order

SQL files **must** be executed in numeric order:
```sql
\i sql/000-ddl.sql      -- Core types and schemas
\i sql/010-api.sql      -- Basic API functions
\i sql/011-json.sql     -- JSON utilities
\i sql/012-throw.sql    -- Error handling
\i sql/013-call.sql     -- Dynamic function calling
\i sql/020-persistence-internal.sql  -- Internal persistence
\i sql/021-persistence-public.sql    -- Public persistence API
```

## Core Patterns

### Function Calling Convention

The `api.call(function_name, json_args)` is the main entry point:
- Returns standardized `api.call_result` with HTTP status codes (200, 400, 404, etc.)
- Automatically converts JSON to typed records: `jsonb_populate_record(NULL::type_name, json)`
- **Limitation**: Only supports functions with 0 or 1 argument (no overloading)

### Error Handling Strategy

Use HTTP-like error codes with custom PostgreSQL error states:
- `api.throw_error()` → 400 Bad Request (`P0400`)
- `api.throw_not_found()` → 404 Not Found (`P0404`) 
- `api.throw_forbidden()` → 403 Forbidden (`P0403`)

### Persistence Pattern

Generic CRUD via reflection:
```sql
-- Auto-generates INSERT/UPDATE/DELETE based on table structure
api_persist.insert_record(record)
api_persist.update_record(record) 
api_persist.fetch_record(NULL::table_type, id, throw_if_not_found)
```

### Web API Integration

See `sample-app/` for complete examples. The pattern:
1. Define typed PL/pgSQL functions (e.g., `task_manager.get_task(task_id_type)`)
2. Web layer calls `api.call('task_manager.get_task', {"id": 123})`
3. Framework handles JSON→type conversion and error mapping

Sample applications:
- `sample-app/task-manager/` - Task management with categories and metadata
- `sample-app/bank-simulator/` - Banking system with accounts and transactions

## Development Workflow

### Adding New API Functions

1. Create schema-namespaced functions (e.g., `task_manager.create_task`)
2. Use custom types for parameters (see `sample-app/task-manager/task-manager.sql` for examples)
3. Return structured data, not just success/failure
4. Test via `api.call()` before building web endpoints

### Database Schema Changes

- Always use the persistence layer for standard CRUD operations
- Custom business logic goes in schema-specific functions
- Use `api.log_*()` functions for debugging (controllable via `api.set_log_level()`)

### Testing Strategy

- Use `sql/test.sql` patterns for SQL-level testing
- REST testing via `sample-app/*/test.rest` files
- Both Python (FastAPI) and Node.js (Express) implementations available

## Key Constraints

- **No function overloading**: `api.call()` only finds the first matching function name
- **Single argument limitation**: Functions can have 0 or 1 parameter only
- **Schema dependency**: Core `api` schema must exist before application schemas
- **Transaction boundaries**: Web requests = single transactions for consistency

## Project-Specific Conventions

- Schemas are feature-bounded (e.g., `task_manager`, `api`, `api_persist`)
- Custom types end with `_type` suffix (e.g., `task_id_type`, `category_create_type`)
- All API functions return structured data (JSONB or custom types)
- Environment variables in `.env` for database connections in sample apps
