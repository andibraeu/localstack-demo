terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region                      = var.region
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    apigateway = "http://localhost:4566"
    iam        = "http://localhost:4566"
    lambda     = "http://localhost:4566"
    s3         = "http://s3.localhost.localstack.cloud:4566"
  }
}

# -----------------------------------------------
# S3 bucket: note data
# -----------------------------------------------
resource "aws_s3_bucket" "notes_data" {
  bucket        = var.data_bucket_name
  force_destroy = true
}

# -----------------------------------------------
# S3 Bucket: Statische Website
# -----------------------------------------------
resource "aws_s3_bucket" "notes_website" {
  bucket        = var.website_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.notes_website.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.notes_website.id
  key          = "index.html"
  source       = "${path.module}/../frontend/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/../frontend/index.html")
}

# -----------------------------------------------
# IAM-Rolle fuer Lambda
# -----------------------------------------------
resource "aws_iam_role" "lambda_role" {
  name = "notes-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_s3" {
  name = "lambda-s3-access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.notes_data.arn,
        "${aws_s3_bucket.notes_data.arn}/*"
      ]
    }]
  })
}

# -----------------------------------------------
# Lambda-Funktion
# -----------------------------------------------
resource "aws_lambda_function" "notes_handler" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.handler"
  runtime       = "nodejs18.x"
  timeout       = 30

  filename         = "${path.module}/../lambda/function.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda/function.zip")

  environment {
    variables = {
      BUCKET_NAME      = var.data_bucket_name
      AWS_ENDPOINT_URL = "http://host.docker.internal:4566"
    }
  }
}

# -----------------------------------------------
# API Gateway (REST API)
# -----------------------------------------------
resource "aws_api_gateway_rest_api" "notes_api" {
  name = "notes-api"
}

resource "aws_api_gateway_resource" "notes" {
  rest_api_id = aws_api_gateway_rest_api.notes_api.id
  parent_id   = aws_api_gateway_rest_api.notes_api.root_resource_id
  path_part   = "notes"
}

# --- GET /notes ---
resource "aws_api_gateway_method" "get_notes" {
  rest_api_id   = aws_api_gateway_rest_api.notes_api.id
  resource_id   = aws_api_gateway_resource.notes.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_notes" {
  rest_api_id             = aws_api_gateway_rest_api.notes_api.id
  resource_id             = aws_api_gateway_resource.notes.id
  http_method             = aws_api_gateway_method.get_notes.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.notes_handler.invoke_arn
}

# --- POST /notes ---
resource "aws_api_gateway_method" "post_notes" {
  rest_api_id   = aws_api_gateway_rest_api.notes_api.id
  resource_id   = aws_api_gateway_resource.notes.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post_notes" {
  rest_api_id             = aws_api_gateway_rest_api.notes_api.id
  resource_id             = aws_api_gateway_resource.notes.id
  http_method             = aws_api_gateway_method.post_notes.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.notes_handler.invoke_arn
}

# --- OPTIONS /notes (CORS) ---
resource "aws_api_gateway_method" "options_notes" {
  rest_api_id   = aws_api_gateway_rest_api.notes_api.id
  resource_id   = aws_api_gateway_resource.notes.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_notes" {
  rest_api_id             = aws_api_gateway_rest_api.notes_api.id
  resource_id             = aws_api_gateway_resource.notes.id
  http_method             = aws_api_gateway_method.options_notes.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.notes_handler.invoke_arn
}

# --- Deployment ---
resource "aws_api_gateway_deployment" "notes" {
  rest_api_id = aws_api_gateway_rest_api.notes_api.id

  depends_on = [
    aws_api_gateway_integration.get_notes,
    aws_api_gateway_integration.post_notes,
    aws_api_gateway_integration.options_notes,
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "dev" {
  rest_api_id   = aws_api_gateway_rest_api.notes_api.id
  deployment_id = aws_api_gateway_deployment.notes.id
  stage_name    = "dev"
}
