# Task Manager API Sample App

This sample app demonstrates how to use the plplg-api to create a simple task management system with a REST API. The app is available in two implementations:

- [Python (FastAPI)](app.py)
- [Node.js (Express)](app.js)

Both implementations provide the same API endpoints and functionality, connecting to a PostgreSQL database with the plplg-api extension.

## Setup

1. Make sure you have PostgreSQL with plplg-api extension installed
2. Run the SQL setup scripts:
   ```bash
   psql -f task-manager.sql
   psql -f task-manager-api.sql
   ```
3. Create a `.env` file with your database connection details:
   ```
   DB_HOST=localhost
   DB_PORT=5515
   DB_NAME=postgres
   DB_USER=postgres
   DB_PASS=postgres
   ```

## Running the API Server

### Python Implementation

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Run the server:
   ```bash
   python app.py
   ```

### Node.js Implementation

1. Install dependencies:
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

## API Endpoints

The server runs on `http://localhost:8000` by default and provides the following endpoints:

### Tasks

- `GET /tasks` - Get all tasks
- `GET /tasks/{task_id}` - Get a specific task by ID
- `POST /tasks` - Create a new task
- `POST /tasks/{task_id}/metadata` - Update task metadata

### Categories

- `GET /categories` - Get all categories
- `GET /categories/{category_id}` - Get a specific category by ID

## Example Requests

See the [test.rest](test.rest) file for example API requests that can be executed using REST Client extensions in various IDEs.

## How It Works

The sample app demonstrates how to use plplg-api's features:

1. Database functions are defined in [task-manager-api.sql](task-manager-api.sql)
2. The web server calls these functions using the `api.call` interface
3. The API handles JSON data, validation, and error responses

Both implementations use the same underlying PostgreSQL functions but with different web frameworks (FastAPI for Python and Express for Node.js).