data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.ec2_role.name
}

locals {
  resolved_ami_id = coalesce(var.ami_id, data.aws_ssm_parameter.al2023.value)
  user_data = templatefile("${path.module}/templates/ec2_user_data.sh.tftpl", {
    backend_port             = var.backend_port
    db_write_host            = var.db_write_host
    db_read_host             = var.db_read_host
    db_name                  = var.db_name
    db_username              = var.db_username
    db_password              = var.db_password
    aws_region               = var.aws_region
    ses_sender_email         = var.ses_sender_email
    backend_app_b64          = var.backend_app_b64
    backend_requirements_b64 = var.backend_requirements_b64
    nginx_conf_b64           = var.nginx_conf_b64
    systemd_service_b64      = var.systemd_service_b64
  })
}

resource "aws_launch_template" "this" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = local.resolved_ami_id
  instance_type = var.instance_type
  user_data     = base64encode(local.user_data)

  iam_instance_profile {
    name = aws_iam_instance_profile.this.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.ec2_security_group_id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.project_name}-backend"
    }
  }
}

resource "aws_autoscaling_group" "this" {
  name                      = "${var.project_name}-asg"
  desired_capacity          = var.desired_capacity
  min_size                  = var.min_size
  max_size                  = var.max_size
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [var.target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_cooldown          = 120

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-backend"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "scale_out_60" {
  name                   = "${var.project_name}-step-scale-60"
  autoscaling_group_name = aws_autoscaling_group.this.name
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "StepScaling"
  estimated_instance_warmup = 180

  step_adjustment {
    metric_interval_lower_bound = 0
    scaling_adjustment          = 1
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_60" {
  alarm_name          = "${var.project_name}-cpu-60"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 60
  alarm_description   = "Scale out by 1 instance when ASG average CPU is >= 60%"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out_60.arn]
}

resource "aws_autoscaling_policy" "scale_out_85" {
  name                   = "${var.project_name}-step-scale-85"
  autoscaling_group_name = aws_autoscaling_group.this.name
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "StepScaling"
  estimated_instance_warmup = 180

  step_adjustment {
    metric_interval_lower_bound = 0
    scaling_adjustment          = 3
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_85" {
  alarm_name          = "${var.project_name}-cpu-85"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Scale out by 3 instances when ASG average CPU is >= 85%"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out_85.arn]
}
