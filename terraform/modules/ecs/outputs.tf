output "cluster_id" {
  description = "The ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "The ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "autoscaling_group_name" {
  description = "The name of the Auto Scaling Group"
  value       = aws_autoscaling_group.ecs.name
}

output "security_group_id" {
  description = "The ID of the ECS security group"
  value       = aws_security_group.ecs_instances.id
}

output "execution_role_arn" {
  description = "The ARN of the ECS execution role"
  value       = aws_iam_role.ecs_execution_role.arn
}

output "task_role_arn" {
  description = "The ARN of the ECS task role"
  value       = aws_iam_role.ecs_task_role.arn
}

output "cloudwatch_log_group_names" {
  description = "Map of service names to CloudWatch Log Group names"
  value       = { for k, v in aws_cloudwatch_log_group.ecs_services : k => v.name }
}