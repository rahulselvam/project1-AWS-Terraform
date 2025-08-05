# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "decoded_user_data" {
  value = base64decode(filebase64("${path.module}/user-data.sh"))
}

output "lb_endpoint" {
  value = "http://${aws_lb.project2.dns_name}"
}

output "application_endpoint" {
  value = "http://${aws_lb.project2.dns_name}/index.php"
}

output "asg_name" {
  value = aws_autoscaling_group.project2.name
}

