variable "project_name" {
  type = string
}

variable "lambda_function_name" {
  type = string
}

variable "lambda_source_dir" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "lambda_security_group_id" {
  type = string
}

variable "db_host" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "ses_sender_email" {
  type = string
}
