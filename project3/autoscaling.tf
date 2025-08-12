resource "aws_launch_template" "frontend" {
  name_prefix   = "frontend-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  
  user_data = base64encode(templatefile("${path.module}/user-data-frontend.sh", {
    internal_alb_dns = aws_lb.internal.dns_name
  }))
}

resource "aws_autoscaling_group" "frontend" {
  name                = "frontend-asg"
  vpc_zone_identifier = module.vpc.private_subnets
  target_group_arns   = [aws_lb_target_group.frontend_tg.arn]
  health_check_type   = "ELB"
  min_size            = 2
  max_size            = 6
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.frontend.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "frontend-asg"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "frontend_scale_up" {
  name                   = "frontend-scale-up"
  scaling_adjustment     = 2
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.frontend.name
}

resource "aws_cloudwatch_metric_alarm" "frontend_cpu_high" {
  alarm_name          = "frontend-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"
  alarm_actions       = [aws_autoscaling_policy.frontend_scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.frontend.name
  }
}

resource "aws_autoscaling_policy" "frontend_scale_down" {
  name                   = "frontend-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.frontend.name
}

resource "aws_cloudwatch_metric_alarm" "frontend_cpu_low" {
  alarm_name          = "frontend-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "10"
  alarm_actions       = [aws_autoscaling_policy.frontend_scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.frontend.name
  }
}