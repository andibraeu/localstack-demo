output "api_url" {
  description = "Base URL of the Notes API on LocalStack"
  value       = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.notes_api.id}/${aws_api_gateway_stage.dev.stage_name}/_user_request_"
}

output "api_notes_endpoint" {
  description = "Full endpoint for /notes"
  value       = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.notes_api.id}/${aws_api_gateway_stage.dev.stage_name}/_user_request_/notes"
}

output "website_url" {
  description = "URL of the static website"
  value       = "http://${var.website_bucket_name}.s3-website.localhost.localstack.cloud:4566"
}

output "data_bucket" {
  description = "Name of the data bucket"
  value       = aws_s3_bucket.notes_data.id
}
