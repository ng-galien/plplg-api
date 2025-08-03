# Sample Applications

This directory contains sample applications demonstrating how to use the plpg-api framework for building database-first APIs.

## Available Sample Apps

### [Task Manager](task-manager/)
A simple task management system with categories and task tracking. Demonstrates basic CRUD operations, relationships, and JSON metadata handling.

- **Features**: Task creation, categorization, status tracking, metadata
- **Demonstrates**: Persistence layer, relationships, JSON handling
- **API**: REST endpoints for tasks and categories
- **Includes**: Complete Python (FastAPI) and Node.js (Express) implementations

### [Bank Simulator](bank-simulator/)
A simple banking system with customers, accounts, and transactions. Shows more complex business logic with financial constraints and atomic operations.

- **Features**: Customer management, account creation, deposits, withdrawals, transfers
- **Demonstrates**: Business logic validation, atomic transactions, error handling
- **API**: Complete banking operations with proper financial constraints
- **Includes**: Both Python (FastAPI) and Node.js (Express) implementations

## Quick Start

Each sample app is self-contained with its own setup instructions, dependencies, and web servers:

- **Task Manager**: See [task-manager/README.md](task-manager/README.md)
- **Bank Simulator**: See [bank-simulator/README.md](bank-simulator/README.md)

## General Setup Process

All sample apps follow this general pattern:

1. Install the core plpg-api framework (from project root):
   ```bash
   psql -f sql/000-ddl.sql
   psql -f sql/010-api.sql
   psql -f sql/011-json.sql
   psql -f sql/012-throw.sql
   psql -f sql/013-call.sql
   psql -f sql/020-persistence-internal.sql
   psql -f sql/021-persistence-public.sql
   ```

2. Install the specific sample app schema and run the web server (see individual README files)

Each sample app demonstrates different aspects of the plpg-api framework with complete, self-contained implementations.
