data "http" "rds_ca_bundle" {
  url = "https://truststore.pki.rds.amazonaws.com/${data.aws_region.current.region}/${data.aws_region.current.region}-bundle.pem"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200 && strcontains(self.response_body, "BEGIN CERTIFICATE")
      error_message = "Could not download the RDS certificate bundle."
    }
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-db-subnets"
  subnet_ids = [for subnet in aws_subnet.private : subnet.id]
}

resource "aws_db_instance" "postgres" {
  identifier     = "${var.name_prefix}-postgres"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "lmnr"
  username = "lmnr"
  password = random_password.postgres.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false
}
