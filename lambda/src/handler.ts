import {
  S3Client,
  PutObjectCommand,
  ListObjectsV2Command,
  GetObjectCommand,
} from "@aws-sdk/client-s3";
import type {
  APIGatewayProxyEvent,
  APIGatewayProxyResult,
} from "aws-lambda";

const BUCKET_NAME = process.env.BUCKET_NAME || "notes-data";

const isLocal = !!process.env.AWS_ENDPOINT_URL;

const s3 = new S3Client({
  region: process.env.AWS_REGION || "eu-central-1",
  ...(isLocal && {
    endpoint: process.env.AWS_ENDPOINT_URL,
    forcePathStyle: true,
    credentials: { accessKeyId: "test", secretAccessKey: "test" },
  }),
});

interface Note {
  id: string;
  title: string;
  content: string;
  createdAt: string;
}

const headers = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

async function createNote(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  const body = JSON.parse(event.body || "{}");

  if (!body.title || !body.content) {
    return {
      statusCode: 400,
      headers,
      body: JSON.stringify({ error: "title and content are required" }),
    };
  }

  const note: Note = {
    id: `note-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    title: body.title,
    content: body.content,
    createdAt: new Date().toISOString(),
  };

  await s3.send(
    new PutObjectCommand({
      Bucket: BUCKET_NAME,
      Key: `${note.id}.json`,
      Body: JSON.stringify(note),
      ContentType: "application/json",
    })
  );

  return {
    statusCode: 201,
    headers,
    body: JSON.stringify(note),
  };
}

async function listNotes(): Promise<APIGatewayProxyResult> {
  const listResult = await s3.send(
    new ListObjectsV2Command({
      Bucket: BUCKET_NAME,
      Prefix: "note-",
    })
  );

  const notes: Note[] = [];

  for (const obj of listResult.Contents || []) {
    const getResult = await s3.send(
      new GetObjectCommand({
        Bucket: BUCKET_NAME,
        Key: obj.Key,
      })
    );
    const text = await getResult.Body?.transformToString();
    if (text) {
      notes.push(JSON.parse(text));
    }
  }

  notes.sort((a, b) => b.createdAt.localeCompare(a.createdAt));

  return {
    statusCode: 200,
    headers,
    body: JSON.stringify(notes),
  };
}

export async function handler(
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> {
  console.log("Event:", JSON.stringify(event, null, 2));

  if (event.httpMethod === "OPTIONS") {
    return { statusCode: 200, headers, body: "" };
  }

  try {
    switch (event.httpMethod) {
      case "POST":
        return await createNote(event);
      case "GET":
        return await listNotes();
      default:
        return {
          statusCode: 405,
          headers,
          body: JSON.stringify({ error: "Method not allowed" }),
        };
    }
  } catch (err) {
    console.error("Error:", err);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ error: "Internal server error" }),
    };
  }
}
