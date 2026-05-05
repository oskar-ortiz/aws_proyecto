output "lambda_function_arn" {
  value = aws_lambda_function.this.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.this.function_name
}

output "lambda_target_group_arn" {
  value = aws_lb_target_group.lambda.arn
}
