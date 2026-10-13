resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = var.subnet_ids # subnets privés, au moins 2 AZ

  tags = {
    Name = "${var.environment}-db-subnet-group"
  }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.environment}-postgres"
  engine         = var.db_engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_encrypted = true

  db_name  = var.db_name
  username = var.username

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  multi_az                = false
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 1
}

resource "aws_security_group" "rds" {
  name        = "${var.environment}-rds-sg"
  description = "PostgreSQL ${var.environment}"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "postgres" {
  for_each = var.allowed_security_groups

  description                  = "PostgreSQL depuis ${each.key}"
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}