provider "aws" {
  region                  = "ap-south-1"
  shared_credentials_files = ["/home/ubuntu/.aws/credentials"]
}

resource "aws_s3_bucket" "my_bucket" {
  bucket        = var.bucket_name
  force_destroy = true
}

# Common IAM role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "common-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Policy for Lambda functions to access S3, SQS, and CloudWatch logs
resource "aws_iam_policy" "lambda_policy" {
  name = "lambda-common-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:SendMessage"
        ]
        Resource = "${aws_sqs_queue.s3_notifications_queue.arn}"
      },
      {
        Effect = "Allow"
        Action = "logs:*"
        Resource = "*"
      }
    ]
  })
}

# Attach policy to the common Lambda role
resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Upload all the Lambda zip files to S3
resource "aws_s3_object" "lambda_zips" {
  for_each = {
    "getdata_lambda_zip"        = "lambda-functions/getdata-lambda.zip"
    "getdata_lambda_layer_zip"  = "lambda-functions/getdata-lambda-layer.zip"
    "analysis_lambda_zip"       = "lambda-functions/analysis-lambda.zip"
    "analysis_lambda_layer1_zip" = "lambda-functions/analysis-lambda-layer1.zip"
    "analysis_lambda_layer2_zip" = "lambda-functions/analysis-lambda-layer2.zip"
  }
  bucket = var.bucket_name
  key    = each.value
  source = "${path.module}/${each.value}"

  depends_on = [aws_s3_bucket.my_bucket]
}

# Lambda Layer resources for each layer file
resource "aws_lambda_layer_version" "getdata_lambda_layer" {
  layer_name          = "getdata-lambda-layer"
  compatible_runtimes = ["python3.13"]
  s3_bucket           = var.bucket_name
  s3_key              = aws_s3_object.lambda_zips["getdata_lambda_layer_zip"].key

  depends_on = [aws_s3_object.lambda_zips]
}

resource "aws_lambda_layer_version" "analysis_lambda_layer1" {
  layer_name          = "analysis-lambda-layer1"
  compatible_runtimes = ["python3.12"]
  s3_bucket           = var.bucket_name
  s3_key              = aws_s3_object.lambda_zips["analysis_lambda_layer1_zip"].key

  depends_on = [aws_s3_object.lambda_zips]
}

resource "aws_lambda_layer_version" "analysis_lambda_layer2" {
  layer_name          = "analysis-lambda-layer2"
  compatible_runtimes = ["python3.12"]
  s3_bucket           = var.bucket_name
  s3_key              = aws_s3_object.lambda_zips["analysis_lambda_layer2_zip"].key

  depends_on = [aws_s3_object.lambda_zips]
}

# Lambda function to upload a JSON file to S3 (Triggered by CloudWatch daily)
resource "aws_lambda_function" "upload_json_lambda" {
  function_name = "getdata-lambda"
  role          = aws_iam_role.lambda_role.arn
  s3_bucket     = var.bucket_name
  s3_key        = aws_s3_object.lambda_zips["getdata_lambda_zip"].key
  handler       = "getdata-lambda.lambda_handler"
  runtime       = "python3.13"
  timeout       = 60

  layers = [
    aws_lambda_layer_version.getdata_lambda_layer.arn  
  ]

  environment {
    variables = {
      BUCKET_NAME = var.bucket_name
    }
  }

  depends_on = [aws_lambda_layer_version.getdata_lambda_layer]
}

# CloudWatch event rule for daily schedule
resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "daily-lambda-trigger"
  description         = "Trigger Lambda function every day"
  schedule_expression = "rate(1 day)"
}

# CloudWatch event target to invoke the Lambda function
resource "aws_cloudwatch_event_target" "invoke_lambda" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "InvokeLambdaFunction"
  arn       = aws_lambda_function.upload_json_lambda.arn
}

# Permission for CloudWatch to invoke Lambda function
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowCloudWatchInvocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_json_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}

# SQS Queue to receive notifications when new JSON is uploaded to S3
resource "aws_sqs_queue" "s3_notifications_queue" {
  name = "s3-json-notifications"
  visibility_timeout_seconds = 60
}

# S3 Bucket Notification to send message to SQS when a new JSON is uploaded
resource "aws_s3_bucket_notification" "s3_event_notifications" {
  bucket = var.bucket_name

  queue {
    queue_arn     = aws_sqs_queue.s3_notifications_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".json"
  }
}

# SQS Queue Policy to allow S3 to send messages
resource "aws_sqs_queue_policy" "s3_to_sqs_policy" {
  queue_url = aws_sqs_queue.s3_notifications_queue.url

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "*"
        },
        Action = "sqs:SendMessage",
        Resource = aws_sqs_queue.s3_notifications_queue.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = "arn:aws:s3:::${var.bucket_name}"
          }
        }
      }
    ]
  })
}

# Lambda function two for data analysis (triggered by SQS event)
resource "aws_lambda_function" "data_analysis_lambda" {
  function_name = "analysis-lambda"
  role          = aws_iam_role.lambda_role.arn
  s3_bucket     = var.bucket_name
  s3_key        = aws_s3_object.lambda_zips["analysis_lambda_zip"].key
  handler       = "analysis-lambda.lambda_handler"
  runtime       = "python3.12"
  timeout       = 60

  layers = [
    aws_lambda_layer_version.analysis_lambda_layer1.arn,   
    aws_lambda_layer_version.analysis_lambda_layer2.arn       
  ]

  environment {
    variables = {
      QUEUE_URL   = aws_sqs_queue.s3_notifications_queue.url
      BUCKET_NAME = var.bucket_name
    }
  }

  depends_on = [
    aws_lambda_layer_version.analysis_lambda_layer1,
    aws_lambda_layer_version.analysis_lambda_layer2
  ]
}

# SQS event source mapping to trigger Lambda function when new messages arrive
resource "aws_lambda_event_source_mapping" "sqs_lambda_trigger" {
  event_source_arn = aws_sqs_queue.s3_notifications_queue.arn
  function_name    = aws_lambda_function.data_analysis_lambda.id
  batch_size       = 10
}

# Permission for Lambda to access SQS
resource "aws_lambda_permission" "allow_sqs_trigger" {
  statement_id  = "AllowSQSTrigger"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_analysis_lambda.function_name
  principal     = "sqs.amazonaws.com"
  source_arn    = aws_sqs_queue.s3_notifications_queue.arn
}


