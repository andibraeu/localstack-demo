/**
 * Integration tests for the notes Lambda function.
 *
 * The handler is imported and called DIRECTLY (not deployed via the
 * Lambda service). The S3 calls inside the handler
 * go against LocalStack — exactly how you would use it in a real project
 * for integration testing.
 *
 * Prerequisite: LocalStack is running (docker compose up).
 */

// Env vars MUST be set BEFORE the handler is imported,
// because the S3 client is configured when the module is loaded.
process.env.AWS_ENDPOINT_URL = process.env.LOCALSTACK_ENDPOINT || "http://localhost:4566";
process.env.BUCKET_NAME = "test-notes-data";
process.env.AWS_REGION = "eu-central-1";

import { handler } from "../../lambda/src/handler";
import type { APIGatewayProxyEvent, APIGatewayProxyResult } from "aws-lambda";
import {
  S3Client,
  CreateBucketCommand,
  ListObjectsV2Command,
  DeleteObjectsCommand,
  DeleteBucketCommand,
  GetObjectCommand,
} from "@aws-sdk/client-s3";

const BUCKET_NAME = "test-notes-data";

const s3 = new S3Client({
  endpoint: process.env.AWS_ENDPOINT_URL,
  region: "eu-central-1",
  credentials: { accessKeyId: "test", secretAccessKey: "test" },
  forcePathStyle: true,
});

function makeEvent(method: string, body?: object): APIGatewayProxyEvent {
  return {
    httpMethod: method,
    path: "/notes",
    headers: { "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : null,
    queryStringParameters: null,
    pathParameters: null,
    multiValueHeaders: {},
    multiValueQueryStringParameters: null,
    isBase64Encoded: false,
    stageVariables: null,
    requestContext: {} as APIGatewayProxyEvent["requestContext"],
    resource: "/notes",
  };
}

describe("Notes handler – integration tests against LocalStack", () => {
  beforeAll(async () => {
    try {
      await s3.send(new CreateBucketCommand({ Bucket: BUCKET_NAME }));
    } catch {
      // Bucket already exists
    }
  });

  afterAll(async () => {
    try {
      const objects = await s3.send(
        new ListObjectsV2Command({ Bucket: BUCKET_NAME })
      );
      if (objects.Contents && objects.Contents.length > 0) {
        await s3.send(
          new DeleteObjectsCommand({
            Bucket: BUCKET_NAME,
            Delete: {
              Objects: objects.Contents.map((o) => ({ Key: o.Key })),
            },
          })
        );
      }
      await s3.send(new DeleteBucketCommand({ Bucket: BUCKET_NAME }));
    } catch {
      // ignore
    }
  });

  it("POST /notes creates a note and stores it in S3", async () => {
    const event = makeEvent("POST", {
      title: "Test note",
      content: "Content of the test note",
    });

    // Call handler DIRECTLY – no Lambda deployment required
    const result: APIGatewayProxyResult = await handler(event);

    expect(result.statusCode).toBe(201);
    const note = JSON.parse(result.body);
    expect(note.title).toBe("Test note");
    expect(note.content).toBe("Content of the test note");
    expect(note.id).toBeDefined();
    expect(note.createdAt).toBeDefined();

    // Verify: is the object really stored in S3 (LocalStack)?
    const s3Obj = await s3.send(
      new GetObjectCommand({
        Bucket: BUCKET_NAME,
        Key: `${note.id}.json`,
      })
    );
    const stored = JSON.parse((await s3Obj.Body?.transformToString()) || "{}");
    expect(stored.title).toBe("Test note");
    expect(stored.id).toBe(note.id);
  });

  it("GET /notes lists all stored notes", async () => {
    // Create two additional notes via the handler
    for (const title of ["Note A", "Note B"]) {
      await handler(makeEvent("POST", { title, content: `Content: ${title}` }));
    }

    const result = await handler(makeEvent("GET"));

    expect(result.statusCode).toBe(200);
    const notes = JSON.parse(result.body);
    expect(notes.length).toBeGreaterThanOrEqual(3);
    expect(notes.some((n: { title: string }) => n.title === "Note A")).toBe(true);
    expect(notes.some((n: { title: string }) => n.title === "Note B")).toBe(true);
  });

  it("POST without title/content returns 400", async () => {
    const result = await handler(makeEvent("POST", { title: "" }));
    expect(result.statusCode).toBe(400);
  });

  it("DELETE returns 405 (Method Not Allowed)", async () => {
    const result = await handler(makeEvent("DELETE"));
    expect(result.statusCode).toBe(405);
  });

  it("OPTIONS returns 200 (CORS preflight)", async () => {
    const result = await handler(makeEvent("OPTIONS"));
    expect(result.statusCode).toBe(200);
    expect(result.headers?.["Access-Control-Allow-Origin"]).toBe("*");
  });
});
