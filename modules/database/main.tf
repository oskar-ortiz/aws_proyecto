resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.db_subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "primary" {
  identifier             = "${var.project_name}-mysql-primary"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.db_security_group_id]
  multi_az               = true
  publicly_accessible    = false
  backup_retention_period = 7
  storage_encrypted      = true
  skip_final_snapshot    = true
  deletion_protection    = false
  apply_immediately      = true

  tags = {
    Name = "${var.project_name}-mysql-primary"
    Role = "writer"
  }
}

resource "aws_db_instance" "replica" {
  identifier                 = "${var.project_name}-mysql-replica"
  replicate_source_db        = aws_db_instance.primary.identifier
  instance_class             = var.db_instance_class
  db_subnet_group_name       = aws_db_subnet_group.this.name
  vpc_security_group_ids     = [var.db_security_group_id]
  publicly_accessible        = false
  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = {
    Name = "${var.project_name}-mysql-replica"
    Role = "reader"
  }
}
