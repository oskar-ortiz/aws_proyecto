resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "ses_rds_access" {
  name = "${var.project_name}-lambda-inline"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "null_resource" "build_lambda_package" {
  triggers = {
    app_hash = filesha256("${var.lambda_source_dir}/app.py")
    req_hash = filesha256("${var.lambda_source_dir}/requirements.txt")
  }

  provisioner "local-exec" {
    command = <<-EOT
      if exist build rmdir /s /q build
      mkdir build
      python -m pip install --upgrade pip >NUL
      python -m pip install -r "${var.lambda_source_dir}\\requirements.txt" -t build
      copy "${var.lambda_source_dir}\\app.py" build\\app.py >NUL
    EOT
    interpreter = ["cmd", "/C"]
    working_dir = var.lambda_source_dir
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${var.lambda_source_dir}/build"
  output_path = "${var.lambda_source_dir}/lambda.zip"

  depends_on = [null_resource.build_lambda_package]
}

resource "aws_lambda_function" "this" {
  function_name    = var.lambda_function_name
  role             = aws_iam_role.lambda_exec.arn
  runtime          = "python3.12"
  handler          = "app.lambda_handler"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      DB_HOST          = var.db_host
      DB_NAME          = var.db_name
      DB_USER          = var.db_username
      DB_PASSWORD      = var.db_password
      SES_SENDER_EMAIL = var.ses_sender_email
      MAX_RETRIES      = "3"
    }
  }
}

resource "aws_lb_target_group" "lambda" {
  name        = substr("${var.project_name}-lambda-tg", 0, 32)
  target_type = "lambda"
}

resource "aws_lambda_permission" "allow_alb" {
  statement_id  = "AllowExecutionFromALB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda.arn
}

resource "aws_lb_target_group_attachment" "lambda" {
  target_group_arn = aws_lb_target_group.lambda.arn
  target_id        = aws_lambda_function.this.arn

  depends_on = [aws_lambda_permission.allow_alb]
}
