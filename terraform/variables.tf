variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "data_bucket_name" {
  description = "Name of the S3 bucket for note data"
  type        = string
  default     = "notes-data"
}

variable "website_bucket_name" {
  description = "Name of the S3 bucket for the static website"
  type        = string
  default     = "notes-website"
}

variable "lambda_function_name" {
  description = "Name der Lambda-Funktion"
  type        = string
  default     = "notes-handler"
}
