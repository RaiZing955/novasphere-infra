output "alb_dns_name" {
  description = "Nom DNS de l'ALB : point d'entree de l'application."
  value       = aws_lb.web.dns_name
}

output "target_group_arn" {
  description = "ARN du target group de l'application."
  value       = aws_lb_target_group.web.arn
}

output "vpc_id" {
  description = "Identifiant du VPC."
  value       = module.vpc.vpc_id
}

output "asg_name" {
  description = "Nom du groupe d'auto-scaling."
  value       = aws_autoscaling_group.web.name
}

output "ssm_parameter_name" {
  description = "Nom (pas la valeur) du secret dans Parameter Store."
  value       = aws_ssm_parameter.db_password.name
}
