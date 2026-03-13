#!/usr/bin/env bash
#
# Deployment of the notes demo to LocalStack using the standard AWS CLI.
# This script transparently shows every single AWS API call.
#
# The trick: AWS_ENDPOINT_URL routes all aws commands to LocalStack.
# This makes it clear that this is just the regular AWS CLI – no extra tool required.
#
set -euo pipefail

export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_DEFAULT_REGION="eu-central-1"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"

ACCOUNT_ID="000000000000"
DATA_BUCKET="notes-data"
WEBSITE_BUCKET="notes-website"
FUNCTION_NAME="notes-handler"
API_NAME="notes-api"
STAGE="dev"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "========================================"
echo "  LocalStack Notes Demo - Deployment"
echo "========================================"
echo ""
echo "  AWS_ENDPOINT_URL=$AWS_ENDPOINT_URL"
echo "  -> All aws commands go against LocalStack"
echo ""

# ------------------------------------------
# 1. Build Lambda function
# ------------------------------------------
echo "[1/6] Building Lambda function..."
cd "$PROJECT_DIR/lambda"
npm install --silent
npm run package
LAMBDA_ZIP="$PROJECT_DIR/lambda/function.zip"
echo "  -> function.zip created ($( du -h "$LAMBDA_ZIP" | cut -f1 ) bytes)"
echo ""

# ------------------------------------------
# 2. Create S3 buckets
# ------------------------------------------
echo "[2/6] Creating S3 buckets..."
aws s3 mb "s3://$DATA_BUCKET" 2>/dev/null || echo "  (Bucket $DATA_BUCKET existiert bereits)"
aws s3 mb "s3://$WEBSITE_BUCKET" 2>/dev/null || echo "  (Bucket $WEBSITE_BUCKET existiert bereits)"
echo "  -> $DATA_BUCKET and $WEBSITE_BUCKET created"
echo ""

# ------------------------------------------
# 3. Configure and upload static website
# ------------------------------------------
echo "[3/6] Configuring static website..."
aws s3 website "s3://$WEBSITE_BUCKET" \
  --index-document index.html

aws s3 cp "$PROJECT_DIR/frontend/index.html" "s3://$WEBSITE_BUCKET/index.html" \
  --content-type "text/html"

WEBSITE_URL="http://${WEBSITE_BUCKET}.s3-website.localhost.localstack.cloud:4566"
echo "  -> Website URL: $WEBSITE_URL"
echo ""

# ------------------------------------------
# 4. Create Lambda function
# ------------------------------------------
echo "[4/6] Creating Lambda function..."

# IAM role (simplified handling by LocalStack)
aws iam create-role \
  --role-name lambda-role \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
  > /dev/null 2>&1 || true

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/lambda-role"

# Delete existing function if it exists
aws lambda delete-function --function-name "$FUNCTION_NAME" 2>/dev/null || true

aws lambda create-function \
  --function-name "$FUNCTION_NAME" \
  --runtime nodejs18.x \
  --handler handler.handler \
  --role "$ROLE_ARN" \
  --zip-file "fileb://$LAMBDA_ZIP" \
  --environment "Variables={BUCKET_NAME=$DATA_BUCKET,AWS_ENDPOINT_URL=http://host.docker.internal:4566}" \
  --timeout 30 > /dev/null

aws lambda wait function-active-v2 --function-name "$FUNCTION_NAME" 2>/dev/null || sleep 2

echo "  -> Lambda function '$FUNCTION_NAME' created"
echo ""

# ------------------------------------------
# 5. Create API Gateway
# ------------------------------------------
echo "[5/6] Creating API Gateway..."

API_ID=$(aws apigateway create-rest-api \
  --name "$API_NAME" \
  --query 'id' --output text)

ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id "$API_ID" \
  --query 'items[0].id' --output text)

# Create /notes resource
NOTES_ID=$(aws apigateway create-resource \
  --rest-api-id "$API_ID" \
  --parent-id "$ROOT_ID" \
  --path-part "notes" \
  --query 'id' --output text)

LAMBDA_ARN="arn:aws:lambda:${AWS_DEFAULT_REGION}:${ACCOUNT_ID}:function:${FUNCTION_NAME}"

for METHOD in GET POST OPTIONS; do
  aws apigateway put-method \
    --rest-api-id "$API_ID" \
    --resource-id "$NOTES_ID" \
    --http-method "$METHOD" \
    --authorization-type "NONE" > /dev/null

  aws apigateway put-integration \
    --rest-api-id "$API_ID" \
    --resource-id "$NOTES_ID" \
    --http-method "$METHOD" \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${AWS_DEFAULT_REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations" \
    > /dev/null
done

# Deployment
aws apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE" > /dev/null

API_URL="http://localhost:4566/restapis/${API_ID}/${STAGE}/_user_request_"
echo "  -> API Gateway created (ID: $API_ID)"
echo ""

# ------------------------------------------
# 6. Summary
# ------------------------------------------
echo "========================================"
echo "  Deployment finished!"
echo "========================================"
echo ""
echo "  Website:     $WEBSITE_URL"
echo "  API:         $API_URL/notes"
echo ""
echo "  Test the API:"
echo "    curl -X POST $API_URL/notes \\"
echo "      -H 'Content-Type: application/json' \\"
echo "      -d '{\"title\":\"Hello\",\"content\":\"First note!\"}'"
echo ""
echo "    curl $API_URL/notes"
echo ""
echo "  Open the website and paste the API endpoint:"
echo "    $API_URL"
echo ""
