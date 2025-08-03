# Bank Simulator

A simple banking system demonstrating the plpg-api framework with customers, accounts, and transactions. Available in both Python (FastAPI) and Node.js (Express) implementations.

## Features

- **Customer Management**: Create and retrieve customer information
- **Account Management**: Create checking/savings accounts with unique account numbers
- **Transactions**: Deposit, withdraw, and transfer money between accounts
- **Balance Tracking**: Real-time balance updates with transaction history
- **Error Handling**: Proper validation for insufficient funds, invalid accounts, etc.

## Setup

1. Make sure you have PostgreSQL with plpg-api extension installed
2. Run the SQL setup scripts in order:
   ```bash
   # First install the core plpg-api (from project root)
   psql -f sql/000-ddl.sql
   psql -f sql/010-api.sql
   psql -f sql/011-json.sql
   psql -f sql/012-throw.sql
   psql -f sql/013-call.sql
   psql -f sql/020-persistence-internal.sql
   psql -f sql/021-persistence-public.sql
   
   # Then install the bank simulator schema
   psql -f bank-simulator.sql
   psql -f bank-simulator-api.sql
   ```

3. Create a `.env` file with your database connection details:
   ```env
   DB_HOST=localhost
   DB_PORT=5432
   DB_NAME=postgres
   DB_USER=postgres
   DB_PASS=postgres
   ```

## Running the API

Choose between Python (FastAPI) or Node.js (Express) implementations:

### Python Implementation

1. Install Python dependencies:
   ```bash
   pip install fastapi uvicorn psycopg2-binary python-dotenv
   ```

2. Run the server:
   ```bash
   python bank-app.py
   ```

### Node.js Implementation

1. Install Node.js dependencies:
   ```bash
   npm install
   ```

2. Run the server:
   ```bash
   npm start
   ```

   For development with auto-reload:
   ```bash
   npm run dev
   ```

Both implementations provide the same API endpoints and functionality. The API will be available at `http://localhost:8000`.

**Note**: The Python implementation includes interactive API documentation at `http://localhost:8000/docs`.

## API Endpoints

### Customers
- `GET /customers/` - List all customers
- `GET /customers/{customer_id}` - Get customer details
- `POST /customers/` - Create new customer

### Accounts
- `GET /customers/{customer_id}/accounts` - Get customer's accounts
- `GET /accounts/{account_number}` - Get account details
- `POST /accounts/` - Create new account

### Transactions
- `POST /transactions/deposit` - Deposit money
- `POST /transactions/withdraw` - Withdraw money
- `POST /transactions/transfer` - Transfer between accounts
- `GET /accounts/{account_number}/transactions` - Get transaction history

## Example Usage

See `bank-test.rest` for complete API examples that can be run with REST Client extensions.

### Quick Start Example

1. Create a customer:
   ```json
   POST /customers/
   {
     "first_name": "John",
     "last_name": "Doe", 
     "email": "john@example.com"
   }
   ```

2. Create an account:
   ```json
   POST /accounts/
   {
     "customer_id": 1,
     "account_type": "checking",
     "initial_balance": 1000.00
   }
   ```

3. Make a deposit:
   ```json
   POST /transactions/deposit
   {
     "account_number": "ACC0000000001",
     "amount": 500.00,
     "description": "Paycheck deposit"
   }
   ```

## Database Schema

- **bank.customer**: Customer information (name, email, phone)
- **bank.account**: Account details (account number, type, balance, status)
- **bank.transaction**: Transaction history (deposits, withdrawals, transfers)

## Key Features Demonstrated

- **Database-first development**: All business logic in PL/pgSQL functions
- **JSON API integration**: Web API calls database functions via `api.call()`
- **Error handling**: Custom error codes for business rules (insufficient funds, etc.)
- **Transaction safety**: Database transactions ensure data consistency
- **Type safety**: Custom PostgreSQL types for API parameters

## Sample Data

The system comes with pre-loaded sample data:
- 3 customers (John Doe, Jane Smith, Bob Johnson)
- 4 accounts with various balances
- Ready for testing transactions

This demonstrates how plpg-api can handle real-world business logic with proper error handling and data validation, all implemented at the database level.
