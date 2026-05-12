resource "aws_lb" "this" {
  name               = substr("${var.project_name}-alb", 0, 32)
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "ec2" {
  name        = substr("${var.project_name}-ec2-tg", 0, 32)
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = var.health_check_path
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-ec2-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Route not found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "admin" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ec2.arn
  }

  condition {
    path_pattern {
      values = ["/admin/*", "/health"]
    }
  }
}

resource "aws_lb_listener_rule" "dashboard" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 15

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ec2.arn
  }

  condition {
    path_pattern {
      values = ["/dashboard", "/dashboard/*"]
    }
  }
}

resource "aws_lb_listener_rule" "api_lambda" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = var.lambda_target_group_arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}
