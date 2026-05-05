variable "project_name" {
  type = string
}

variable "ami_id" {
  type    = string
  default = null
}

variable "instance_type" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ec2_security_group_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "desired_capacity" {
  type = number
}

variable "min_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "backend_port" {
  type = number
}

variable "db_write_host" {
  type = string
}

variable "db_read_host" {
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

variable "aws_region" {
  type = string
}

variable "backend_app_b64" {
  type = string
}

variable "backend_requirements_b64" {
  type = string
}

variable "nginx_conf_b64" {
  type = string
}

variable "systemd_service_b64" {
  type = string
}
