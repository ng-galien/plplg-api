from fastapi import FastAPI, HTTPException, Depends, Request
import psycopg2
from psycopg2.extras import RealDictCursor
import os
import json
from pydantic import BaseModel
from datetime import datetime
from dotenv import load_dotenv


# Load environment variables from .env file
load_dotenv()

# Initialize FastAPI app
app = FastAPI(
    title="Task Manager API", 
    description="REST API for Task Manager",
    version="1.0.0"
)

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5515")
DB_NAME = os.getenv("DB_NAME", "postgres")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASS = os.getenv("DB_PASS", "postgres")

def get_db_connection():
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASS,
            cursor_factory=RealDictCursor
        )
        return conn
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database connection error: {str(e)}")

def get_db():
    conn = get_db_connection()
    try:
        yield conn
    finally:
        conn.close()

def call_api_function(conn, function_name, args=None):
    cursor = conn.cursor()
    try:
        if args is None:
            args = {}
        args_json = json.dumps(args)
        cursor.execute("SELECT * FROM api.call(%s, %s::jsonb)", (function_name, args_json))
        result = cursor.fetchone()
        if result["result_code"] >= 400:
            raise HTTPException(status_code=result["result_code"], detail=result["result_message"])
        return result["result_data"]
    except HTTPException as http_exc:
        #print stack trace for debugging
        import traceback
        traceback.print_exc()
        conn.rollback()
        raise
    except Exception as e:
        #print stack trace for debugging
        import traceback
        traceback.print_exc()
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()

@app.get("/tasks/")
def list_tasks(conn=Depends(get_db)):
    return call_api_function(conn, "task_manager.get_all_tasks")

@app.get("/tasks/{task_id}")
def get_task(task_id: int, conn=Depends(get_db)):
    return call_api_function(conn, "task_manager.get_task", {"id": task_id})

@app.post("/tasks/")
async def create_task(request: Request, conn=Depends(get_db)):
    task_data = await request.json()
    return call_api_function(conn, "task_manager.create_task", task_data)

@app.get("/categories/")
def list_categories(conn=Depends(get_db)):
    return call_api_function(conn, "task_manager.get_all_categories")

@app.get("/categories/{category_id}")
def get_category(category_id: int, conn=Depends(get_db)):
    return call_api_function(conn, "task_manager.get_category", {"id": category_id})

if __name__ == "__main__":
    import uvicorn
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run(app, host=host, port=port)