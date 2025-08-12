output "frontend_alb_dns" {
  value = aws_lb.external.dns_name
  description = "Public DNS of the external load balancer (frontend)"
}

output "backend_alb_dns" {
  value = aws_lb.internal.dns_name
  description = "Internal DNS of the backend ALB"
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.frontend.name
  description = "Name of the frontend Auto Scaling Group"
}

output "backend_private_ip" {
  value = aws_instance.backend.private_ip
  description = "Private IP of the backend EC2 instance"
}

output "rds_endpoint" {
  value       = aws_db_instance.mysql.endpoint
  description = "RDS MySQL endpoint"
}
