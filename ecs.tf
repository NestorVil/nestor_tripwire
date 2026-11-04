locals {
  laminar_images = {
    app_server = "ghcr.io/lmnr-ai/app-server:v0.3.2@sha256:89ef89fc27d537abc5d86bf3d358b53c43d1976dc2d4f3601fe4769e725d796e"
    frontend   = "ghcr.io/lmnr-ai/frontend:v0.3.2@sha256:b2e3f7875f28b9794f755a373d80d784dd2044b9f9666a3d8e6ccc8765bf7960"
  }

  laminar_url     = "http://${aws_lb.main.dns_name}"
  data_box_ip     = aws_instance.data_box.private_ip
  app_server_host = "app-server.${aws_service_discovery_private_dns_namespace.internal.name}"

  app_server_environment = {
    PORT                    = "8000"
    GRPC_PORT               = "8001"
    ENVIRONMENT             = "FULL"
    NEXT_PUBLIC_URL         = local.laminar_url
    CLICKHOUSE_URL          = "http://${local.data_box_ip}:8123"
    CLICKHOUSE_USER         = "ch_user"
    CLICKHOUSE_RO_USER      = "ch_user"
    REDIS_URL               = "redis://${local.data_box_ip}:6379"
    QUICKWIT_ENABLED        = "true"
    QUICKWIT_SEARCH_URL     = "http://${local.data_box_ip}:7280"
    QUICKWIT_INGEST_URL     = "http://${local.data_box_ip}:7281"
    QUICKWIT_SPANS_INDEX_ID = "spans_v2"
    RABBITMQ_AUTO_RECONNECT = "true"
  }

  # Environment variable name => key in the tripwire/laminar secret
  app_server_secrets = {
    DATABASE_URL           = "DATABASE_URL"
    DATABASE_SSL_ROOT_CERT = "DATABASE_SSL_ROOT_CERT"
    CLICKHOUSE_PASSWORD    = "CLICKHOUSE_PASSWORD"
    CLICKHOUSE_RO_PASSWORD = "CLICKHOUSE_PASSWORD"
    SHARED_SECRET_TOKEN    = "SHARED_SECRET_TOKEN"
    AEAD_SECRET_KEY        = "AEAD_SECRET_KEY"
    RABBITMQ_URL           = "RABBITMQ_URL"
  }

  frontend_environment = {
    PORT                       = "5667"
    HOSTNAME                   = "0.0.0.0"
    ENVIRONMENT                = "FULL"
    BACKEND_URL                = "http://${local.app_server_host}:8000"
    BACKEND_RT_URL             = "http://${local.app_server_host}:8002"
    NEXTAUTH_URL               = local.laminar_url
    NEXT_PUBLIC_URL            = local.laminar_url
    LAMINAR_TELEMETRY_DISABLED = "true"
    # max_open_connections: room for the migration tool's leaked connections (default pool is 10)
    CLICKHOUSE_URL      = "http://${local.data_box_ip}:8123?max_open_connections=1000"
    CLICKHOUSE_USER     = "ch_user"
    QUICKWIT_SEARCH_URL = "http://${local.data_box_ip}:7280"
    REDIS_URL           = "redis://${local.data_box_ip}:6379"
  }

  frontend_secrets = {
    DATABASE_URL           = "DATABASE_URL"
    DATABASE_SSL_ROOT_CERT = "DATABASE_SSL_ROOT_CERT"
    NEXTAUTH_SECRET        = "NEXTAUTH_SECRET"
    SHARED_SECRET_TOKEN    = "SHARED_SECRET_TOKEN"
    CLICKHOUSE_PASSWORD    = "CLICKHOUSE_PASSWORD"
    AEAD_SECRET_KEY        = "AEAD_SECRET_KEY"
  }
}

resource "aws_ecs_cluster" "main" {
  name = var.name_prefix
}

resource "aws_service_discovery_private_dns_namespace" "internal" {
  name = "${var.name_prefix}.internal"
  vpc  = aws_vpc.main.id
}

resource "aws_service_discovery_service" "app_server" {
  name = "app-server"

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.internal.id
    routing_policy = "MULTIVALUE"

    dns_records {
      type = "A"
      ttl  = 10
    }
  }
}

resource "aws_ecs_task_definition" "app_server" {
  family                   = "${var.name_prefix}-app-server"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 2048
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([{
    name      = "app-server"
    image     = local.laminar_images.app_server
    essential = true
    portMappings = [
      { containerPort = 8000, protocol = "tcp" },
      { containerPort = 8001, protocol = "tcp" },
      { containerPort = 8002, protocol = "tcp" },
    ]
    environment = [for name, value in local.app_server_environment : { name = name, value = value }]
    secrets = [for name, key in local.app_server_secrets : {
      name      = name
      valueFrom = "${aws_secretsmanager_secret.laminar.arn}:${key}::"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.laminar["app-server"].name
        awslogs-region        = data.aws_region.current.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.name_prefix}-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 2048
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([{
    name         = "frontend"
    image        = local.laminar_images.frontend
    essential    = true
    portMappings = [{ containerPort = 5667, protocol = "tcp" }]
    environment  = [for name, value in local.frontend_environment : { name = name, value = value }]
    secrets = [for name, key in local.frontend_secrets : {
      name      = name
      valueFrom = "${aws_secretsmanager_secret.laminar.arn}:${key}::"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.laminar["frontend"].name
        awslogs-region        = data.aws_region.current.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "app_server" {
  name                              = "${var.name_prefix}-app-server"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.app_server.arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 60
  wait_for_steady_state             = true

  network_configuration {
    subnets          = [for subnet in aws_subnet.private : subnet.id]
    security_groups  = [aws_security_group.app_server.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_server.arn
    container_name   = "app-server"
    container_port   = 8000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.app_server.arn
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_lb_listener_rule.app_server]
}

resource "aws_ecs_service" "frontend" {
  name                              = "${var.name_prefix}-frontend"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.frontend.arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 600
  wait_for_steady_state             = true

  network_configuration {
    subnets          = [for subnet in aws_subnet.private : subnet.id]
    security_groups  = [aws_security_group.frontend.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 5667
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_lb_listener.http]
}
