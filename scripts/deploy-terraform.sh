#!/usr/bin/env bash
#
# Deployment of the notes demo to LocalStack using Terraform (tflocal).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "========================================"
echo "  LocalStack Notes Demo - Terraform"
echo "========================================"
echo ""

# Build Lambda
echo "[1/3] Building Lambda function..."
cd "$PROJECT_DIR/lambda"
npm install --silent
npm run package
echo ""

# Run Terraform
echo "[2/3] Terraform init & apply..."
cd "$PROJECT_DIR/terraform"
tflocal init -input=false
tflocal apply -auto-approve -input=false
echo ""

# Show results
echo "[3/3] Deployment finished!"
echo ""
tflocal output
echo ""
echo "Paste the 'api_url' value as API endpoint into the website."
echo ""
