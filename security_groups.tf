resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Load balancer: HTTP from allowed IPs"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "frontend" {
  name        = "${var.name_prefix}-frontend-sg"
  description = "Laminar frontend tasks"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "app_server" {
  name        = "${var.name_prefix}-appserver-sg"
  description = "Laminar app-server tasks"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "data" {
  name        = "${var.name_prefix}-data-sg"
  description = "Data box: ClickHouse, Valkey, RabbitMQ, Quickwit"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "RDS Postgres"
  vpc_id      = aws_vpc.main.id
}

locals {
  security_group_ids = {
    alb        = aws_security_group.alb.id
    frontend   = aws_security_group.frontend.id
    app_server = aws_security_group.app_server.id
    data       = aws_security_group.data.id
    rds        = aws_security_group.rds.id
  }

  internal_rules = {
    frontend_from_alb           = { target = "frontend", source = "alb", port = 5667, description = "Dashboard from ALB" }
    app_server_from_alb         = { target = "app_server", source = "alb", port = 8000, description = "SDK and SQL API from ALB" }
    app_server_from_frontend    = { target = "app_server", source = "frontend", port = 8000, description = "Internal API from frontend" }
    realtime_from_frontend      = { target = "app_server", source = "frontend", port = 8002, description = "Realtime SSE from frontend" }
    clickhouse_from_app_server  = { target = "data", source = "app_server", port = 8123, description = "ClickHouse from app-server" }
    clickhouse_from_frontend    = { target = "data", source = "frontend", port = 8123, description = "ClickHouse from frontend" }
    valkey_from_app_server      = { target = "data", source = "app_server", port = 6379, description = "Valkey from app-server" }
    valkey_from_frontend        = { target = "data", source = "frontend", port = 6379, description = "Valkey from frontend" }
    rabbitmq_from_app_server    = { target = "data", source = "app_server", port = 5672, description = "RabbitMQ from app-server" }
    quickwit_from_app_server    = { target = "data", source = "app_server", port = 7280, description = "Quickwit search from app-server" }
    quickwit_from_frontend      = { target = "data", source = "frontend", port = 7280, description = "Quickwit search from frontend" }
    quickwit_ingest_from_server = { target = "data", source = "app_server", port = 7281, description = "Quickwit ingest from app-server" }
    postgres_from_app_server    = { target = "rds", source = "app_server", port = 5432, description = "Postgres from app-server" }
    postgres_from_frontend      = { target = "rds", source = "frontend", port = 5432, description = "Postgres from frontend" }
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  for_each = toset(var.allowed_cidrs)

  security_group_id = aws_security_group.alb.id
  description       = "HTTP from allowed IP"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "internal" {
  for_each = local.internal_rules

  security_group_id            = local.security_group_ids[each.value.target]
  referenced_security_group_id = local.security_group_ids[each.value.source]
  description                  = each.value.description
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
}

resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  for_each = local.security_group_ids

  security_group_id = each.value
  description       = "All outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
