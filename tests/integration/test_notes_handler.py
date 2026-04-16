import json
import os
import sys
import unittest
from pathlib import Path

import boto3


PROJECT_ROOT = Path(__file__).resolve().parents[2]
LAMBDA_DIR = PROJECT_ROOT / "lambda"
sys.path.insert(0, str(LAMBDA_DIR))

os.environ.setdefault("AWS_ENDPOINT_URL", "http://localhost:4566")
os.environ.setdefault("AWS_REGION", "eu-central-1")
os.environ.setdefault("AWS_ACCESS_KEY_ID", "test")
os.environ.setdefault("AWS_SECRET_ACCESS_KEY", "test")
os.environ["BUCKET_NAME"] = os.environ.get("BUCKET_NAME", "test-notes-data")

from handler import handler  # noqa: E402


class NotesHandlerIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bucket = os.environ["BUCKET_NAME"]
        cls.s3 = boto3.client(
            "s3",
            endpoint_url=os.environ["AWS_ENDPOINT_URL"],
            region_name=os.environ["AWS_REGION"],
            aws_access_key_id="test",
            aws_secret_access_key="test",
        )
        try:
            cls.s3.create_bucket(Bucket=cls.bucket)
        except Exception:
            pass
        cls._cleanup_notes()

    @classmethod
    def tearDownClass(cls):
        cls._cleanup_notes()

    @classmethod
    def _cleanup_notes(cls):
        objects = cls.s3.list_objects_v2(Bucket=cls.bucket, Prefix="note-").get("Contents", [])
        if objects:
            cls.s3.delete_objects(
                Bucket=cls.bucket,
                Delete={"Objects": [{"Key": obj["Key"]} for obj in objects if obj.get("Key")]},
            )

    def _event(self, method, body=None):
        return {
            "httpMethod": method,
            "path": "/notes",
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(body) if body is not None else None,
        }

    def test_post_creates_note_and_stores_in_s3(self):
        resp = handler(self._event("POST", {"title": "Test note", "content": "Hello"}), None)
        self.assertEqual(resp["statusCode"], 201)
        note = json.loads(resp["body"])
        self.assertTrue(note["id"].startswith("note-"))

        obj = self.s3.get_object(Bucket=self.bucket, Key=f"{note['id']}.json")
        stored = json.loads(obj["Body"].read().decode("utf-8"))
        self.assertEqual(stored["title"], "Test note")

    def test_get_lists_notes(self):
        handler(self._event("POST", {"title": "Note A", "content": "A"}), None)
        handler(self._event("POST", {"title": "Note B", "content": "B"}), None)

        resp = handler(self._event("GET"), None)
        self.assertEqual(resp["statusCode"], 200)
        notes = json.loads(resp["body"])
        titles = {n["title"] for n in notes}
        self.assertIn("Note A", titles)
        self.assertIn("Note B", titles)

    def test_validation_and_methods(self):
        invalid = handler(self._event("POST", {"title": ""}), None)
        self.assertEqual(invalid["statusCode"], 400)

        method_not_allowed = handler(self._event("DELETE"), None)
        self.assertEqual(method_not_allowed["statusCode"], 405)

        options = handler(self._event("OPTIONS"), None)
        self.assertEqual(options["statusCode"], 200)
        self.assertEqual(options["headers"].get("Access-Control-Allow-Origin"), "*")


if __name__ == "__main__":
    unittest.main()
