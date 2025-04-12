variable "environment" {
  description = "The environment (dev, prod)"
  type        = string
}

variable "region" {
  description = "The AWS region"
  type        = string
}

variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "service_names" {
  description = "List of ECS service names to monitor"
  type        = list(string)
}

variable "critical_services" {
  description = "List of critical services that require additional monitoring"
  type        = list(string)
  default     = ["api-gateway", "discovery-server"]
}

variable "load_balancer_arn" {
  description = "ARN of the load balancer (without the full ARN prefix)"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the target group (without the full ARN prefix)"
  type        = string
}

variable "error_threshold_4xx" {
  description = "Threshold for 4XX errors before alerting"
  type        = number
  default     = 50 # Alert if more than 50 4XX errors in 1 minute
}

variable "error_threshold_5xx" {
  description = "Threshold for 5XX errors before alerting"
  type        = number
  default     = 10 # Alert if more than 10 5XX errors in 1 minute
}

variable "devops_email" {
  description = "Email address for DevOps team notifications"
  type        = string
  default     = "devops-team@example.com"
}

variable "enable_pagerduty" {
  description = "Whether to enable PagerDuty integrations"
  type        = bool
  default     = false
}

variable "pagerduty_service_key" {
  description = "PagerDuty service integration key"
  type        = string
  default     = ""
  sensitive   = true
}