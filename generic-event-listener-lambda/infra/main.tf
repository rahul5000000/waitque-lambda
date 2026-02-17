terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "archive_file" "generic_event_lambda_package" {
  type        = "zip"
  source_dir  = "../lambda/dist"
  output_path = "../lambda/generic_event_lambda_package.zip"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_secretsmanager_secret" "rds_credentials" {
  arn = "arn:aws:secretsmanager:us-east-1:667573506753:secret:waitque-rds-postgres-credentials-wE2E9S"
}

resource "aws_iam_policy" "generic_event_lambda_policy" {
  name = "waitque-generic-event-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # CloudWatch Logs
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },

      # SQS
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = var.questionnaire_response_viewed_queue_arn
      },

      # Secrets Manager read access
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = data.aws_secretsmanager_secret.rds_credentials.arn
      }
    ]
  })
}

resource "aws_security_group" "lambda_sg" {
  name        = "generic-event-lambda-sg"
  description = "Security group for Lambda to talk to ECS services"
  vpc_id      = data.aws_vpc.default.id

  # Lambda needs OUTBOUND traffic to reach ECS tasks
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # No inbound rules needed – Lambda never accepts inbound connections
}

resource "aws_iam_role" "generic_event_lambda_role" {
  name = "waitque-generic-event-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.generic_event_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "attach_generic_event_policy" {
  role       = aws_iam_role.generic_event_lambda_role.name
  policy_arn = aws_iam_policy.generic_event_lambda_policy.arn
}

resource "aws_lambda_function" "generic_event_consumer" {
  filename         = data.archive_file.generic_event_lambda_package.output_path
  source_code_hash = data.archive_file.generic_event_lambda_package.output_base64sha256

  function_name = "waitque-generic-event-consumer"
  role          = aws_iam_role.generic_event_lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  architectures = ["arm64"]

  memory_size = 512
  timeout     = 30
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.questionnaire_response_viewed_queue_arn
  function_name    = aws_lambda_function.generic_event_consumer.arn

  batch_size                         = 10
  maximum_batching_window_in_seconds  = 5

  function_response_types = ["ReportBatchItemFailures"]

  enabled = true
}