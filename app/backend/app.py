import os
import time
from contextlib import closing

import pymysql
from dotenv import load_dotenv
from flask import Flask, jsonify, request

load_dotenv("/opt/university/app/.env")

app = Flask(__name__)


def get_connection(read_only=False):
    host = os.getenv("DB_READ_HOST") if read_only else os.getenv("DB_WRITE_HOST")
    return pymysql.connect(
        host=host,
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        database=os.getenv("DB_NAME"),
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True,
        connect_timeout=5,
    )


def ensure_schema():
    statements = [
        """
        CREATE TABLE IF NOT EXISTS enrollments (
            id INT AUTO_INCREMENT PRIMARY KEY,
            student_name VARCHAR(120) NOT NULL,
            student_email VARCHAR(190) NOT NULL,
            course_code VARCHAR(40) NOT NULL,
            status VARCHAR(20) NOT NULL DEFAULT 'REGISTERED',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS email_failures (
            id INT AUTO_INCREMENT PRIMARY KEY,
            enrollment_id INT NULL,
            recipient_email VARCHAR(190) NOT NULL,
            error_message TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """,
    ]

    last_error = None
    for _ in range(15):
        try:
            with closing(get_connection(read_only=False)) as conn:
                with conn.cursor() as cursor:
                    for statement in statements:
                        cursor.execute(statement)
            return
        except Exception as exc:
            last_error = exc
            time.sleep(10)

    raise RuntimeError(f"Unable to initialize schema: {last_error}")


@app.get("/health")
def health():
    return jsonify({"status": "ok"}), 200


@app.get("/admin/health")
def admin_health():
    return jsonify({"service": "admin-backend", "status": "ok"}), 200


@app.post("/admin/enrollments")
def create_enrollment():
    payload = request.get_json(silent=True) or {}
    required = ["student_name", "student_email", "course_code"]
    missing = [field for field in required if not payload.get(field)]
    if missing:
        return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

    sql = """
        INSERT INTO enrollments (student_name, student_email, course_code, status)
        VALUES (%s, %s, %s, 'REGISTERED')
    """

    with closing(get_connection(read_only=False)) as conn:
        with conn.cursor() as cursor:
            cursor.execute(
                sql,
                (
                    payload["student_name"],
                    payload["student_email"],
                    payload["course_code"],
                ),
            )
            enrollment_id = cursor.lastrowid

    return (
        jsonify(
            {
                "message": "Enrollment created",
                "enrollment_id": enrollment_id,
                "next_step": "/api/confirm",
            }
        ),
        201,
    )


@app.get("/admin/enrollments")
def list_enrollments():
    with closing(get_connection(read_only=True)) as conn:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, student_name, student_email, course_code, status, created_at
                FROM enrollments
                ORDER BY created_at DESC
                LIMIT 100
                """
            )
            rows = cursor.fetchall()

    return jsonify({"items": rows, "source": "read-replica"}), 200


if __name__ == "__main__":
    ensure_schema()
    app.run(host="0.0.0.0", port=int(os.getenv("APP_PORT", "8000")))
else:
    ensure_schema()
