variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for all resource names."
  type        = string
  default     = "university-enrollment"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "Two availability zones for HA deployment."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets where the ALB and NAT live."
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "app_subnet_cidrs" {
  description = "CIDRs for private application subnets."
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "db_subnet_cidrs" {
  description = "CIDRs for private database subnets."
  type        = list(string)
  default     = ["10.20.20.0/24", "10.20.21.0/24"]
}

variable "ami_id" {
  description = "AMI ID for application instances. Leave null to use the latest Amazon Linux 2023 AMI."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type for backend nodes."
  type        = string
  default     = "t3.micro"
}

variable "backend_port" {
  description = "Internal Gunicorn port."
  type        = number
  default     = 8000
}

variable "asg_desired_capacity" {
  description = "Desired capacity for the Auto Scaling Group."
  type        = number
  default     = 2
}

variable "asg_min_size" {
  description = "Minimum ASG size."
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum ASG size."
  type        = number
  default     = 6
}

variable "db_name" {
  description = "MySQL database name."
  type        = string
  default     = "university"
}

variable "db_username" {
  description = "MySQL master username."
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "MySQL master password."
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class for primary and replica."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Storage in GB for the primary RDS instance."
  type        = number
  default     = 20
}

variable "ses_sender_email" {
  description = "Verified SES sender email. In sandbox, the recipient must also be verified."
  type        = string
}
