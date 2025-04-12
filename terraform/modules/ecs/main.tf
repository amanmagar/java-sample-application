/*
 * ECS Module for Microservices Deployment
 * This module creates the ECS cluster, task definitions, and services for the microservices application
 */

# Create ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "${var.environment}-ecs-cluster"
    Environment = var.environment
  }
}

# Create ECS Capacity Providers
resource "aws_ecs_capacity_provider" "main" {
  name = "${var.environment}-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 5
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 80
    }
  }

  tags = {
    Name        = "${var.environment}-capacity-provider"
    Environment = var.environment
  }
}

# Associate Capacity Provider with Cluster
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.main.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.main.name
  }
}

# Security Group for ECS Instances
resource "aws_security_group" "ecs_instances" {
  name        = "${var.environment}-ecs-instances-sg"
  description = "Security Group for ECS Instances"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-ecs-instances-sg"
    Environment = var.environment
  }
}

# IAM Role for ECS Execution
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.environment}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-ecs-execution-role"
    Environment = var.environment
  }
}

# Attach policies to ECS Execution Role
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_ecr_read_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECR-ReadOnly"
}

resource "aws_iam_role_policy" "secrets_access" {
  name = "${var.environment}-secrets-access"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-ecs-task-role"
    Environment = var.environment
  }
}

# Attach policies to ECS Task Role
resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "${var.environment}-ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# EC2 Launch Template
resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.environment}-ecs-template-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.ecs_instances.id]
  
  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_ec2_profile.name
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 30
      volume_type = "gp3"
      encrypted   = true
    }
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config
    echo "ECS_ENABLE_CONTAINER_METADATA=true" >> /etc/ecs/ecs.config
    echo "ECS_ENABLE_SPOT_INSTANCE_DRAINING=true" >> /etc/ecs/ecs.config
    echo "ECS_AVAILABLE_LOGGING_DRIVERS=[\"json-file\",\"awslogs\"]" >> /etc/ecs/ecs.config
    yum install -y aws-cfn-bootstrap aws-cli
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment}-ecs-instance"
      Environment = var.environment
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "${var.environment}-ecs-volume"
      Environment = var.environment
    }
  }
}

# IAM Role for EC2 ECS Instances
resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.environment}-ecs-instance-role"

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

  tags = {
    Name        = "${var.environment}-ecs-instance-role"
    Environment = var.environment
  }
}

# Attach policies to EC2 Instance Role
resource "aws_iam_role_policy_attachment" "ecs_ec2_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_ssm_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ecs_ec2_profile" {
  name = "${var.environment}-ecs-ec2-profile"
  role = aws_iam_role.ecs_instance_role.name
}

# Auto Scaling Group
resource "aws_autoscaling_group" "ecs" {
  name                = "${var.environment}-ecs-asg"
  vpc_zone_identifier = var.private_subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  
  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-ecs-instance"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "ecs_scale_up" {
  name                   = "${var.environment}-ecs-scale-up"
  autoscaling_group_name = aws_autoscaling_group.ecs.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "ecs_scale_down" {
  name                   = "${var.environment}-ecs-scale-down"
  autoscaling_group_name = aws_autoscaling_group.ecs.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

# CloudWatch Alarms for Auto Scaling
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.environment}-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
  }
  alarm_description = "Scale up if CPU utilization is above 70% for 2 minutes"
  alarm_actions     = [aws_autoscaling_policy.ecs_scale_up.arn]
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.environment}-cpu-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 30
  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
  }
  alarm_description = "Scale down if CPU utilization is below 30% for 2 minutes"
  alarm_actions     = [aws_autoscaling_policy.ecs_scale_down.arn]
}

# Create CloudWatch Log Groups for each service
resource "aws_cloudwatch_log_group" "ecs_services" {
  for_each = var.services

  name              = "/ecs/${var.environment}/${each.key}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "/ecs/${var.environment}/${each.key}"
    Environment = var.environment
    Service     = each.key
  }
}