terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "network" {
  source = "./modules/network"

  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  app_subnet_cidrs    = var.app_subnet_cidrs
  db_subnet_cidrs     = var.db_subnet_cidrs
  availability_zones  = var.availability_zones
}

module "security" {
  source = "./modules/security"

  project_name = var.project_name
  vpc_id       = module.network.vpc_id
}

module "database" {
  source = "./modules/database"

  project_name         = var.project_name
  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = var.db_password
  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  db_subnet_ids        = module.network.db_subnet_ids
  db_security_group_id = module.security.rds_security_group_id
}

module "lambda_email" {
  source = "./modules/lambda"

  project_name             = var.project_name
  lambda_function_name     = "${var.project_name}-enrollment-email"
  lambda_source_dir        = "${path.root}/lambda"
  private_subnet_ids       = module.network.app_subnet_ids
  lambda_security_group_id = module.security.lambda_security_group_id
  db_host                  = module.database.primary_endpoint
  db_name                  = var.db_name
  db_username              = var.db_username
  db_password              = var.db_password
  ses_sender_email         = var.ses_sender_email
}

module "alb" {
  source = "./modules/alb"

  project_name              = var.project_name
  vpc_id                    = module.network.vpc_id
  public_subnet_ids         = module.network.public_subnet_ids
  alb_security_group_id     = module.security.alb_security_group_id
  lambda_function_name      = module.lambda_email.lambda_function_name
  lambda_function_arn       = module.lambda_email.lambda_function_arn
  lambda_target_group_arn   = module.lambda_email.lambda_target_group_arn
  health_check_path         = "/health"
}

module "compute" {
  source = "./modules/compute"

  project_name              = var.project_name
  ami_id                    = var.ami_id
  instance_type             = var.instance_type
  private_subnet_ids        = module.network.app_subnet_ids
  ec2_security_group_id     = module.security.ec2_security_group_id
  target_group_arn          = module.alb.ec2_target_group_arn
  desired_capacity          = var.asg_desired_capacity
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  backend_port              = var.backend_port
  db_write_host             = module.database.primary_endpoint
  db_read_host              = module.database.replica_endpoint
  db_name                   = var.db_name
  db_username               = var.db_username
  db_password               = var.db_password
  ses_sender_email          = var.ses_sender_email
  aws_region                = var.aws_region
  backend_app_b64           = base64encode(file("${path.root}/app/backend/app.py"))
  backend_requirements_b64  = base64encode(file("${path.root}/app/backend/requirements.txt"))
  nginx_conf_b64            = base64encode(file("${path.root}/nginx/nginx.conf"))
  systemd_service_b64       = base64encode(file("${path.root}/app/backend/university-backend.service"))
}
