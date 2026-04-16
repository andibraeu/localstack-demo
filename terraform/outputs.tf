output "api_url" {
  description = "Base URL of the Notes API on Ministack"
  value       = "http://${aws_api_gateway_rest_api.notes_api.id}.execute-api.localhost:4566/${aws_api_gateway_stage.dev.stage_name}"
}

output "api_notes_endpoint" {
  description = "Full endpoint for /notes"
  value       = "http://${aws_api_gateway_rest_api.notes_api.id}.execute-api.localhost:4566/${aws_api_gateway_stage.dev.stage_name}/notes"
}

output "website_url" {
  description = "URL of the static website entry object"
  value       = "http://localhost:4566/${var.website_bucket_name}/index.html"
}

output "data_bucket" {
  description = "Name of the data bucket"
  value       = aws_s3_bucket.notes_data.id
}
