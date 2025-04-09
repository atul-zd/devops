output "lambda_name" {
  value = aws_lambda_function.s3_trigger_lambda.function_name
}

output "s3_bucket" {
  value = aws_s3_bucket.lambda_trigger_bucket.bucket
}
