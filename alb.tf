resource "aws_lb" "main" {
  name               = "${var.name_prefix}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]
}

resource "aws_lb_target_group" "frontend" {
  name                 = "${var.name_prefix}-frontend-tg"
  port                 = 5667
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = aws_vpc.main.id
  deregistration_delay = 30

  health_check {
    path    = "/"
    matcher = "200-399"
  }
}

resource "aws_lb_target_group" "app_server" {
  name                 = "${var.name_prefix}-appserver-tg"
  port                 = 8000
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = aws_vpc.main.id
  deregistration_delay = 30

  health_check {
    path    = "/health"
    matcher = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener_rule" "app_server" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/v1/*", "/health"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_server.arn
  }
}
