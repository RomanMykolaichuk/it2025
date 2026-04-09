from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import psycopg2
import os

app = FastAPI()

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:admin@localhost:5432/ex2025")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://127.0.0.1:5500",
        "http://localhost:5500"
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_connection():
    return psycopg2.connect(DATABASE_URL)

@app.get("/")
def fun1():
    return {"field": "value_get"}

@app.delete("/")
def fun2():
    return {"field": "value"}

@app.get("/reports")
def get_reports():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, username, content FROM reports LIMIT 5;")
    rows = cursor.fetchall()

    result = []
    for row in rows:
        result.append({
            "id": row[0],
            "username": row[1],
            "content": row[2]
        })

    cursor.close()
    conn.close()
    return result