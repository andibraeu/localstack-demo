import json
import os
import time
import uuid

import boto3


BUCKET_NAME = os.environ.get("BUCKET_NAME", "notes-data")
AWS_REGION = os.environ.get("AWS_REGION", "eu-central-1")
AWS_ENDPOINT_URL = os.environ.get("AWS_ENDPOINT_URL")

s3_kwargs = {"region_name": AWS_REGION}
if AWS_ENDPOINT_URL:
    s3_kwargs["endpoint_url"] = AWS_ENDPOINT_URL
    s3_kwargs["aws_access_key_id"] = "test"
    s3_kwargs["aws_secret_access_key"] = "test"

s3 = boto3.client("s3", **s3_kwargs)

HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
}


def _response(status_code: int, body):
    return {
        "statusCode": status_code,
        "headers": HEADERS,
        "body": json.dumps(body) if not isinstance(body, str) else body,
    }


def _create_note(event):
    payload = json.loads(event.get("body") or "{}")
    title = payload.get("title")
    content = payload.get("content")

    if not title or not content:
        return _response(400, {"error": "title and content are required"})

    note = {
        "id": f"note-{int(time.time() * 1000)}-{uuid.uuid4().hex[:6]}",
        "title": title,
        "content": content,
        "createdAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }

    s3.put_object(
        Bucket=BUCKET_NAME,
        Key=f"{note['id']}.json",
        Body=json.dumps(note).encode("utf-8"),
        ContentType="application/json",
    )

    return _response(201, note)


def _list_notes():
    objects = s3.list_objects_v2(Bucket=BUCKET_NAME, Prefix="note-").get("Contents", [])
    notes = []

    for obj in objects:
        data = s3.get_object(Bucket=BUCKET_NAME, Key=obj["Key"])["Body"].read()
        notes.append(json.loads(data.decode("utf-8")))

    notes.sort(key=lambda n: n["createdAt"], reverse=True)
    return _response(200, notes)


def handler(event, context):
    method = event.get("httpMethod", "")

    if method == "OPTIONS":
        return {"statusCode": 200, "headers": HEADERS, "body": ""}

    try:
        if method == "POST":
            return _create_note(event)
        if method == "GET":
            return _list_notes()
        return _response(405, {"error": "Method not allowed"})
    except Exception as err:
        return _response(500, {"error": "Internal server error", "message": str(err)})
