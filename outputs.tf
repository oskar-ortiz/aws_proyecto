output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer."
  value       = module.alb.alb_dns_name
}

output "admin_url" {
  description = "Base URL for the admin backend path."
  value       = "http://${module.alb.alb_dns_name}/admin/"
}

output "api_lambda_url" {
  description = "Base URL for the Lambda integration path."
  value       = "http://${module.alb.alb_dns_name}/api/"
}

output "rds_primary_endpoint" {
  description = "Primary RDS endpoint for write traffic."
  value       = module.database.primary_endpoint
}

output "rds_read_replica_endpoint" {
  description = "Read replica endpoint for read traffic."
  value       = module.database.replica_endpoint
}
