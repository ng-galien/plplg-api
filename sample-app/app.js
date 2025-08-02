const express = require('express');
const { Pool } = require('pg');
const dotenv = require('dotenv');

// Load environment variables from .env file
dotenv.config();

// Initialize Express app
const app = express();
app.use(express.json());

// Database configuration
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || '5515',
  database: process.env.DB_NAME || 'postgres',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASS || 'postgres'
};

// Create a new pool instance
const pool = new Pool(dbConfig);

// Test database connection
pool.connect((err, client, release) => {
  if (err) {
    console.error('Database connection error:', err.message);
  } else {
    console.log('Connected to PostgreSQL database');
    release();
  }
});

// Function to call API functions in the database
async function callApiFunction(functionName, args = {}) {
  const client = await pool.connect();
  try {
    const argsJson = JSON.stringify(args);
    const result = await client.query(
      'SELECT * FROM api.call($1, $2::jsonb)',
      [functionName, argsJson]
    );
    
    const apiResult = result.rows[0];
    
    if (apiResult.result_code >= 400) {
      const error = new Error(apiResult.result_message);
      error.statusCode = apiResult.result_code;
      throw error;
    }
    
    return apiResult.result_data;
  } catch (error) {
    console.error('Error calling API function:', error);
    if (error.statusCode) {
      throw error;
    } else {
      const serverError = new Error(error.message);
      serverError.statusCode = 500;
      throw serverError;
    }
  } finally {
    client.release();
  }
}

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  const statusCode = err.statusCode || 500;
  res.status(statusCode).json({
    error: err.message || 'Internal Server Error'
  });
});

// API Routes

// Get all tasks
app.get('/tasks', async (req, res, next) => {
  try {
    const tasks = await callApiFunction('task_manager.get_all_tasks');
    res.json(tasks);
  } catch (error) {
    next(error);
  }
});

// Get a specific task
app.get('/tasks/:taskId', async (req, res, next) => {
  try {
    const taskId = parseInt(req.params.taskId);
    const task = await callApiFunction('task_manager.get_task', { id: taskId });
    res.json(task);
  } catch (error) {
    next(error);
  }
});

// Create a new task
app.post('/tasks', async (req, res, next) => {
  try {
    const taskData = req.body;
    const newTask = await callApiFunction('task_manager.create_task', taskData);
    res.status(201).json(newTask);
  } catch (error) {
    next(error);
  }
});

// Create a new task
app.post('/tasks/:taskId/metadata',
    async (req, res, next) => {
  try {
    const metadatUpdate = {
        metadata_info: req.body,
        task_id: parseInt(req.params.taskId)
    }
    const updatedTask = await callApiFunction('task_manager.set_task_metadata', metadatUpdate);
    res.status(201).json(updatedTask);
  } catch (error) {
    next(error);
  }
});

// Get all categories
app.get('/categories', async (req, res, next) => {
  try {
    const categories = await callApiFunction('task_manager.get_all_categories');
    res.json(categories);
  } catch (error) {
    next(error);
  }
});

// Get a specific category
app.get('/categories/:categoryId', async (req, res, next) => {
  try {
    const categoryId = parseInt(req.params.categoryId);
    const category = await callApiFunction('task_manager.get_category', { id: categoryId });
    res.json(category);
  } catch (error) {
    next(error);
  }
});

// Start the server
const PORT = process.env.PORT || 8000;
const HOST = process.env.HOST || '0.0.0.0';

app.listen(PORT, HOST, () => {
  console.log(`Server running on http://${HOST}:${PORT}`);
});