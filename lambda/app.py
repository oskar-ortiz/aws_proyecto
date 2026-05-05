import json
import os
import time
from contextlib import closing

import boto3
import pymysql
from botocore.exceptions import ClientError

ses = boto3.client("ses")


def _connect():
    return pymysql.connect(
        host=os.environ["DB_HOST"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        database=os.environ["DB_NAME"],
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True,
        connect_timeout=5,
    )


def _store_failure(enrollment_id, recipient_email, error_message):
    with closing(_connect()) as conn:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS email_failures (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    enrollment_id INT NULL,
                    recipient_email VARCHAR(190) NOT NULL,
                    error_message TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
                """
            )
            cursor.execute(
                """
                INSERT INTO email_failures (enrollment_id, recipient_email, error_message)
                VALUES (%s, %s, %s)
                """,
                (enrollment_id, recipient_email, error_message[:2000]),
            )


def _send_email(recipient_email, student_name, course_code):
    ses.send_email(
        Source=os.environ["SES_SENDER_EMAIL"],
        Destination={"ToAddresses": [recipient_email]},
        Message={
            "Subject": {"Data": "Confirmacion de matricula"},
            "Body": {
                "Text": {
                    "Data": (
                        f"Hola {student_name}, tu matricula para el curso "
                        f"{course_code} fue registrada correctamente."
                    )
                }
            },
        },
    )


def _is_retryable_throttling(error):
    if not isinstance(error, ClientError):
        return False

    code = error.response.get("Error", {}).get("Code", "")
    return code in {
        "Throttling",
        "ThrottlingException",
        "TooManyRequestsException",
        "ProvisionedThroughputExceededException",
    }


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "statusDescription": f"{status_code} {'OK' if status_code < 400 else 'ERROR'}",
        "isBase64Encoded": False,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def lambda_handler(event, context):
    del context
    body = event.get("body") or "{}"
    if event.get("isBase64Encoded"):
        import base64

        body = base64.b64decode(body).decode("utf-8")

    payload = json.loads(body)

    enrollment_id = payload.get("enrollment_id")
    recipient_email = payload.get("student_email")
    student_name = payload.get("student_name", "estudiante")
    course_code = payload.get("course_code", "N/A")

    if not recipient_email:
        return _response(400, {"error": "student_email is required"})

    max_retries = int(os.environ.get("MAX_RETRIES", "3"))
    last_error = None

    for attempt in range(1, max_retries + 1):
        try:
            _send_email(recipient_email, student_name, course_code)
            return _response(
                200,
                {
                    "message": "Confirmation email sent",
                    "attempt": attempt,
                    "recipient": recipient_email,
                },
            )
        except Exception as exc:
            last_error = str(exc)
            if _is_retryable_throttling(exc) and attempt < max_retries:
                time.sleep(2 ** (attempt - 1))
                continue
            break

    _store_failure(enrollment_id, recipient_email, last_error or "Unknown error")
    return _response(
        500,
        {
            "message": "Email delivery failed after retries",
            "attempts": max_retries,
            "error": last_error,
        },
    )
