provider "aws" {
  region    = "us-east-2"
}
terraform {
    backend "s3" {
        bucket = "tf-state-23948067"
        key = "weather/terraform.tfstate"
        dynamodb_table = "weather-state"
        region = "us-east-2"
    }
}

resource "aws_s3_bucket" "state-bucket" {
    bucket = "tf-state-23948067"
    versioning {
        enabled = true
    }
}

resource "aws_dynamodb_table" "state-table" {
    name = "weather-state"
    hash_key = "LockID"
    attribute {
        name = "LockID"
        type = "S"
    }
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "weather" {
  filename         = "/tmp/weather.zip"
  function_name    = "weather"
  role             = "${aws_iam_role.iam_for_lambda.arn}"
  handler          = "weather"
  source_code_hash = "${filebase64sha256("/tmp/weather.zip")}"
  runtime          = "go1.x"
}
