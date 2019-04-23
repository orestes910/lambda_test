#AWS
provider "aws" {
  region = "us-east-2"
}

terraform {
  backend "s3" {
    bucket         = "tf-state-23948067"
    key            = "weather/terraform.tfstate"
    dynamodb_table = "weather-state"
    region         = "us-east-2"
  }
}

#API and Usage Plan
resource "aws_api_gateway_rest_api" "weather_api" {
  name = "weather"
}

resource "aws_api_gateway_resource" "resource" {
  path_part   = "resource"
  parent_id   = "${aws_api_gateway_rest_api.weather_api.root_resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.weather_api.id}"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id      = "${aws_api_gateway_rest_api.weather_api.id}"
  resource_id      = "${aws_api_gateway_resource.resource.id}"
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id = "${aws_api_gateway_rest_api.weather_api.id}"
  resource_id = "${aws_api_gateway_resource.resource.id}"
  http_method = "${aws_api_gateway_method.method.http_method}"
  type        = "AWS_PROXY"
  uri         = "arn:aws:apigateway:us-east-2:lambda:path/2015-03-31/functions/${aws_lambda_function.weather.arn}/invocations"
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = "${aws_api_gateway_rest_api.weather_api.id}"
  stage_name  = "stage-1"
}

resource "aws_api_gateway_usage_plan" "weather_usage_plan" {
  name         = "weather-usage"
  product_code = "weather"

  api_stages {
    api_id = "${aws_api_gateway_rest_api.weather_api.id}"
    stage  = "${aws_api_gateway_deployment.deployment.stage_name}"
  }

  quota_settings {
    limit  = 20
    offset = 2
    period = "WEEK"
  }

  throttle_settings {
    burst_limit = 5
    rate_limit  = 10
  }
}

resource "aws_api_gateway_api_key" "weather_key" {
  name = "weather"
}

resource "aws_api_gateway_usage_plan_key" "weather_plan_key" {
  key_id        = "${aws_api_gateway_api_key.weather_key.id}"
  key_type      = "API_KEY"
  usage_plan_id = "${aws_api_gateway_usage_plan.weather_usage_plan.id}"
}

#Roles and Permissions
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

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.weather.arn}"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.weather_api.execution_arn}/stage-1/method/resource"
}

#Lambda
resource "aws_lambda_function" "weather" {
  filename         = "/tmp/weather.zip"
  function_name    = "weather"
  role             = "${aws_iam_role.iam_for_lambda.arn}"
  handler          = "weather"
  source_code_hash = "${filebase64sha256("/tmp/weather.zip")}"
  runtime          = "go1.x"
}
