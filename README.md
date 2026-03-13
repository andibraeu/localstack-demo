# LocalStack Colloquium Demo

A notes app that uses **S3**, **Lambda**, and **API Gateway** – running entirely
locally with [LocalStack](https://localstack.cloud), no real AWS account needed.

## Architecture

```
Browser ──► S3 (Static Website)     ← index.html
Browser ──► API Gateway ──► Lambda ──► S3 (Daten-Bucket)
```

| Component      | Description                                      |
| -------------- | ------------------------------------------------ |
| S3 Website     | Hosts the static HTML/JS page                    |
| API Gateway    | HTTP REST API with GET and POST on `/notes`      |
| Lambda         | TypeScript handler: create and read notes        |
| S3 Data        | Stores notes as JSON files                       |

## Prerequisites

- **Docker** and **Docker Compose**
- **Node.js >= 18**
- **LocalStack Pro Auth Token** (stored in `.env`)
- **AWS CLI v2** (supports `AWS_ENDPOINT_URL`) – for path 1
- **Terraform** + **tflocal** (`pip install terraform-local`) – for path 2

## Quickstart

### 1. Prepare the repository

```bash
cp .env.example .env
# Put LOCALSTACK_AUTH_TOKEN into .env

npm run install:all
```

### 2. Start LocalStack

```bash
npm start
# or: docker compose up -d
```

Wait until LocalStack is ready:

```bash
curl http://localhost:4566/_localstack/health
```

### 3a. Deployment with AWS CLI (path 1 – transparent)

```bash
npm run deploy
# or: ./scripts/setup.sh
```

The script sets `AWS_ENDPOINT_URL=http://localhost:4566` and then uses the
regular `aws` CLI. This shows that the commands are exactly the same as
against real AWS – only the endpoint is different.

### 3b. Deployment with Terraform (path 2 – Infrastructure as Code)

```bash
npm run build:lambda      # Lambda-ZIP bauen
npm run deploy:terraform   # oder: ./scripts/deploy-terraform.sh
```

### 4. Test the app in the browser

1. Open the **website URL** shown in the terminal
2. Paste the **API endpoint** into the configuration field of the website
3. Create notes and fetch them

### 5. Inspect data in S3

```bash
export AWS_ENDPOINT_URL=http://localhost:4566
aws s3 ls s3://notes-data/ --region eu-central-1
aws s3 cp s3://notes-data/<note-id>.json - | jq
```

## Integration tests

The tests import the handler function **directly** and invoke it.
The S3 calls inside the handler go against LocalStack –
no Lambda deployment required. This illustrates the core value of LocalStack:
existing production code works locally without changes.

```bash
# Prerequisite: LocalStack is running
npm test
```

### What is being tested?

| Test                            | Verifies                                                 |
| ------------------------------- | -------------------------------------------------------- |
| POST creates a note             | Lambda stores JSON in S3 and returns 201                 |
| GET lists all notes             | Lambda reads all objects from S3 and returns an array    |
| POST with invalid body          | Lambda returns 400                                       |
| Unsupported HTTP method         | Lambda returns 405                                       |

## Project structure

```
localstack-demo/
├── docker-compose.yml         # LocalStack Pro container
├── lambda/                    # Lambda function (TypeScript)
│   ├── src/handler.ts         #   GET/POST /notes handler
│   ├── package.json
│   └── tsconfig.json
├── frontend/                  # Static website
│   └── index.html
├── terraform/                 # IaC with Terraform
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── tests/                     # Integration tests
│   ├── jest.config.ts         # Jest configuration
│   └── integration/
│       └── notes.test.ts      # Integration tests for notes API
├── scripts/
│   ├── setup.sh               # Deployment via AWS CLI
│   └── deploy-terraform.sh    # Deployment via tflocal
├── package.json               # Root package with convenience scripts
└── README.md
```

## npm scripts

| Script                  | Description                                  |
| ----------------------- | -------------------------------------------- |
| `npm start`             | Start LocalStack (docker compose up)         |
| `npm stop`              | Stop LocalStack                              |
| `npm run build:lambda`  | Build Lambda function and package as ZIP     |
| `npm run deploy`        | Deployment with AWS CLI (shell script)       |
| `npm run deploy:terraform` | Deployment with Terraform/tflocal        |
| `npm test`              | Run integration tests                        |
| `npm run install:all`   | Install dependencies in all packages         |
| `npm run clean`         | Clean everything (containers, build artifacts) |

## Suggested talk flow (approx. 90 minutes)

1. **Introduction** (15 min) – What is LocalStack? Why develop locally?
2. **Live demo setup** (10 min) – `docker compose up`, LocalStack is running
3. **Deployment with AWS CLI** (15 min) – Create services step by step
4. **Test the app in the browser** (10 min) – Create notes, inspect S3
5. **Terraform variant** (15 min) – Deploy the same infra declaratively
6. **Integration tests** (15 min) – Run Jest tests live
7. **Discussion / Q&A** (10–20 min)

## Useful commands

```bash
# Set once, then all aws commands will target LocalStack:
export AWS_ENDPOINT_URL=http://localhost:4566

# List all S3 buckets
aws s3 ls --region eu-central-1

# List Lambda functions
aws lambda list-functions --region eu-central-1

# List API Gateways
aws apigateway get-rest-apis --region eu-central-1

# View Lambda logs
aws logs describe-log-groups --region eu-central-1
```
