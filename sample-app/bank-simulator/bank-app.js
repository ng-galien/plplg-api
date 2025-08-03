const express = require('express');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
app.use(express.json());

// Database configuration
const pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5515,
    database: process.env.DB_NAME || 'postgres',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASS || 'postgres'
});

// Helper function to call API functions
async function callApiFunction(functionName, args = null) {
    const client = await pool.connect();
    try {
        const argsJson = args ? JSON.stringify(args) : '{}';
        const result = await client.query('SELECT * FROM api.call($1, $2::jsonb)', [functionName, argsJson]);
        const response = result.rows[0];
        
        if (response.result_code >= 400) {
            const error = new Error(response.result_message);
            error.status = response.result_code;
            throw error;
        }
        
        return response.result_data;
    } finally {
        client.release();
    }
}

// Middleware to handle database API calls
function dbCall(functionName, argsExtractor = () => ({}), statusCode = 200) {
    return async (req, res, next) => {
        try {
            const args = argsExtractor(req);
            const result = await callApiFunction(functionName, args);
            res.status(statusCode).json(result);
        } catch (error) {
            next(error);
        }
    };
}

// Error handling middleware
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(err.status || 500).json({
        error: err.message || 'Internal server error'
    });
});

// Root endpoint
app.get('/', (req, res) => {
    res.json({
        message: 'Bank Simulator API is running',
        version: '1.0.0',
        endpoints: {
            customers: '/customers/',
            accounts: '/accounts/',
            transactions: '/transactions/',
            docs: 'No interactive docs available for Node.js version'
        }
    });
});

// Customer endpoints
app.get('/customers/', dbCall('bank.get_all_customers'));

app.get('/customers/:customer_id', dbCall(
    'bank.get_customer',
    (req) => ({ id: parseInt(req.params.customer_id) })
));

app.post('/customers/', dbCall(
    'bank.create_customer',
    (req) => req.body,
    201
));

// Account endpoints
app.get('/customers/:customer_id/accounts', dbCall(
    'bank.get_customer_accounts',
    (req) => ({ id: parseInt(req.params.customer_id) })
));

app.get('/accounts/:account_number', dbCall(
    'bank.get_account_by_number',
    (req) => ({ account_number: req.params.account_number })
));

app.post('/accounts/', dbCall(
    'bank.create_account',
    (req) => ({
        customer_id: parseInt(req.body.customer_id),
        account_type: req.body.account_type || 'checking',
        initial_balance: parseFloat(req.body.initial_balance || 0.00)
    }),
    201
));

// Transaction endpoints
app.post('/transactions/deposit', dbCall(
    'bank.deposit',
    (req) => ({
        account_number: req.body.account_number,
        amount: parseFloat(req.body.amount),
        description: req.body.description
    })
));

app.post('/transactions/withdraw', dbCall(
    'bank.withdraw',
    (req) => ({
        account_number: req.body.account_number,
        amount: parseFloat(req.body.amount),
        description: req.body.description
    })
));

app.post('/transactions/transfer', dbCall(
    'bank.transfer',
    (req) => ({
        from_account_number: req.body.from_account_number,
        to_account_number: req.body.to_account_number,
        amount: parseFloat(req.body.amount),
        description: req.body.description
    })
));

app.get('/accounts/:account_number/transactions', dbCall(
    'bank.get_account_transactions',
    (req) => ({ account_number: req.params.account_number })
));

const PORT = process.env.PORT || 8000;
app.listen(PORT, () => {
    console.log(`Bank Simulator API running on http://localhost:${PORT}`);
    console.log('Available endpoints:');
    console.log('- GET /customers/');
    console.log('- GET /customers/{id}');
    console.log('- POST /customers/');
    console.log('- GET /customers/{id}/accounts');
    console.log('- GET /accounts/{account_number}');
    console.log('- POST /accounts/');
    console.log('- POST /transactions/deposit');
    console.log('- POST /transactions/withdraw');
    console.log('- POST /transactions/transfer');
    console.log('- GET /accounts/{account_number}/transactions');
});
