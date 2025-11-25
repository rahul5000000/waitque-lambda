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
  region = "us-east-1" # change if your bucket is in another region
}

# Zip the Lambda package (includes node_modules after you run npm install)
data "archive_file" "lambda_package" {
  type        = "zip"
  source_dir  = "../lambda"
  output_path = "lambda_package.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "waitque-image-resizer-lambda-role"

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

resource "aws_iam_policy" "lambda_s3_policy" {
  name = "waitque-image-resizer-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::waitque-upload-bucket/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

resource "aws_lambda_function" "image_resizer" {
  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  function_name = "waitque-image-resizer"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  architectures = ["arm64"]

  memory_size = 1024
  timeout     = 30

  environment {
    variables = {
      BUCKET_NAME = "waitque-upload-bucket",
      KEYCLOAK_CLIENT_ID = "waitque-lambda",
      KEYCLOAK_CLIENT_SECRET = "${var.customer_service_client_secret}"
      KEYCLOAK_BASE_URL = "${var.keycloak_base_url}"
      COMPANY_SERVICE_BASE_URL = "${var.company_service_base_url}"
    }
  }
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "allow-s3-invoke-resizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_resizer.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::waitque-upload-bucket"
}

resource "aws_s3_bucket_notification" "raw_upload_trigger" {
  bucket = "waitque-upload-bucket"

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_resizer.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "RAW/logo/"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}