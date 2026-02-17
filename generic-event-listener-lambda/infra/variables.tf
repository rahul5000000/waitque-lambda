variable "questionnaire_response_viewed_queue_arn" {
  description = "questionnaire_response_viewed_queue ARN"
  type        = string
  sensitive   = false
  default     = "arn:aws:sqs:us-east-1:667573506753:questionnaire-response-viewed-queue"
}

variable "db_host" {
  description = "DB Host"
  type        = string
  sensitive   = false
  default     = "waitque-postgres-db.c6xsmmeuyp5z.us-east-1.rds.amazonaws.com"
}

variable "db_name" {
  description = "DB Name"
  type        = string
  sensitive   = false
  default     = "waitque"
}

variable "db_schema" {
  description = "DB Schema"
  type        = string
  sensitive   = false
  default     = "waitque"
}

variable "db_security_group_id" {
  description = "DB Security Group ID"
  type        = string
  sensitive   = false
  default     = "sg-0e6d1c8fdb1ed24bf"
}


variable "db_secret_arn" {
  description = "DB Secrets Manager ARN"
  type        = string
  sensitive   = false
  default     = "arn:aws:secretsmanager:us-east-1:667573506753:secret:waitque-api-db-credentials-staging-9Gab3S"
}