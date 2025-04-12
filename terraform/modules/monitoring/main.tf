/*
 * Monitoring Module
 * Sets up CloudWatch dashboards and alarms for ECS services with focus on error rates
 */

# SNS Topic for Alarms
resource "aws_sns_topic" "alarms" {
  name = "${var.environment}-alarms-topic"
  
  tags = {
    Name        = "${var.environment}-alarms-topic"
    Environment = var.environment
  }
}

# CloudWatch Dashboard for Services
resource "aws_cloudwatch_dashboard" "service_dashboard" {
  dashboard_name = "${var.environment}-services-dashboard"
  
  dashboard_body = jsonencode({
    widgets = concat(
      # CPU and Memory utilization widgets
      [
        {
          type   = "metric"
          width  = 12
          height = 6
          properties = {
            metrics = [
              for service_name in var.service_names : 
              ["AWS/ECS", "CPUUtilization", "ServiceName", service_name, "ClusterName", var.cluster_name]
            ]
            period  = 300
            stat    = "Average"
            region  = var.region
            title   = "ECS Services CPU Utilization"
            view    = "timeSeries"
          }
        },
        {
          type   = "metric"
          width  = 12
          height = 6
          properties = {
            metrics = [
              for service_name in var.service_names : 
              ["AWS/ECS", "MemoryUtilization", "ServiceName", service_name, "ClusterName", var.cluster_name]
            ]
            period  = 300
            stat    = "Average"
            region  = var.region
            title   = "ECS Services Memory Utilization"
            view    = "timeSeries"
          }
        }
      ],
      # API Gateway 4xx and 5xx error widgets
      [
        {
          type   = "metric"
          width  = 12
          height = 6
          properties = {
            metrics = [
              ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "TargetGroup", var.target_group_arn, { label = "4XX Errors" }],
              ["AWS/ApplicationELB", "HTTPCode_ELB_4XX_Count", "LoadBalancer", var.load_balancer_arn, { label = "ALB 4XX Errors" }]
            ]
            period  = 300
            stat    = "Sum"
            region  = var.region
            title   = "HTTP 4XX Errors"
            view    = "timeSeries"
          }
        },
        {
          type   = "metric"
          width  = 12
          height = 6
          properties = {
            metrics = [
              ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "TargetGroup", var.target_group_arn, { label = "5XX Errors" }],
              ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.load_balancer_arn, { label = "ALB 5XX Errors" }]
            ]
            period  = 300
            stat    = "Sum"
            region  = var.region
            title   = "HTTP 5XX Errors"
            view    = "timeSeries"
          }
        }
      ],
      # Service request latency
      [
        {
          type   = "metric"
          width  = 12
          height = 6
          properties = {
            metrics = [
              ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.load_balancer_arn, { period = 60, stat = "p50" }],
              ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.load_balancer_arn, { period = 60, stat = "p90" }],
              ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.load_balancer_arn, { period = 60, stat = "p99" }]
            ]
            period  = 60
            region  = var.region
            title   = "API Response Times (P50, P90, P99)"
            view    = "timeSeries"
          }
        },
        {
          type   = "metric"
          width  = 12
          height = 6
          properties = {
            metrics = [
              ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.load_balancer_arn]
            ]
            period  = 300
            stat    = "Sum"
            region  = var.region
            title   = "Total Request Count"
            view    = "timeSeries"
          }
        }
      ]
    )
  })
}

# 4XX Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "http_4xx_errors" {
  alarm_name          = "${var.environment}-4xx-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_4XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = var.error_threshold_4xx
  alarm_description   = "This metric monitors 4XX error rate"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    LoadBalancer = var.load_balancer_arn
  }

  tags = {
    Name        = "${var.environment}-4xx-error-rate"
    Environment = var.environment
  }
}

# 5XX Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "http_5xx_errors" {
  alarm_name          = "${var.environment}-5xx-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = var.error_threshold_5xx
  alarm_description   = "This metric monitors 5XX error rate"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    LoadBalancer = var.load_balancer_arn
  }

  tags = {
    Name        = "${var.environment}-5xx-error-rate"
    Environment = var.environment
  }
}

# Alarm for API Gateway Service
resource "aws_cloudwatch_metric_alarm" "api_gateway_health" {
  alarm_name          = "${var.environment}-api-gateway-health"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "This metric monitors API Gateway service health"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    TargetGroup  = var.target_group_arn
    LoadBalancer = var.load_balancer_arn
  }

  tags = {
    Name        = "${var.environment}-api-gateway-health"
    Environment = var.environment
  }
}

# Service-specific CPU and Memory alarms for critical services
resource "aws_cloudwatch_metric_alarm" "service_cpu" {
  for_each = { for idx, name in var.service_names : name => name if contains(var.critical_services, name) }
  
  alarm_name          = "${var.environment}-${each.value}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "CPU utilization high for ${each.value} service"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    ServiceName = each.value
    ClusterName = var.cluster_name
  }

  tags = {
    Name        = "${var.environment}-${each.value}-cpu-high"
    Environment = var.environment
  }
}

# Create subscription for DevOps team email
resource "aws_sns_topic_subscription" "devops_email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.devops_email
}