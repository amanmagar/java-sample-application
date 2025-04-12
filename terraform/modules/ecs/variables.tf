variable "environment" {
  description = "The environment (dev, prod)"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID where resources will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "The private subnet IDs where ECS instances will be launched"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "The public subnet IDs where load balancers will be created"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "The security group ID of the ALB"
  type        = string
}

variable "ami_id" {
  description = "The AMI ID to use for ECS instances (should be ECS-optimized)"
  type        = string
  default     = "ami-0557a15b87f6559cf" # Amazon ECS-optimized Amazon Linux 2 AMI
}

variable "instance_type" {
  description = "The EC2 instance type to use for ECS instances"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "SSH key name for ECS instances"
  type        = string
  default     = null
}

variable "min_size" {
  description = "Minimum size of the ECS Auto Scaling Group"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum size of the ECS Auto Scaling Group"
  type        = number
  default     = 10
}

variable "desired_capacity" {
  description = "Desired capacity of the ECS Auto Scaling Group"
  type        = number
  default     = 2
}

variable "services" {
  description = "Map of service names to service configurations"
  type        = map(object({
    container_port    = number
    host_port         = number
    cpu               = number
    memory            = number
    desired_count     = number
    max_count         = number
    min_count         = number
    health_check_path = string
    auto_scaling      = bool
    secrets           = map(string)
    environment       = map(string)
  }))
  default = {
    "api-gateway" = {
      container_port    = 8080
      host_port         = 8080
      cpu               = 256
      memory            = 512
      desired_count     = 2
      max_count         = 4
      min_count         = 1
      health_check_path = "/actuator/health"
      auto_scaling      = true
      secrets           = {}
      environment       = {
        "SPRING_PROFILES_ACTIVE" = "docker"
      }
    },
    "discovery-server" = {
      container_port    = 8761
      host_port         = 8761
      cpu               = 256
      memory            = 512
      desired_count     = 2
      max_count         = 2
      min_count         = 2
      health_check_path = "/actuator/health"
      auto_scaling      = false
      secrets           = {}
      environment       = {
        "SPRING_PROFILES_ACTIVE" = "docker"
      }
    },
    "product-service" = {
      container_port    = 8080
      host_port         = 0
      cpu               = 256
      memory            = 512
      desired_count     = 2
      max_count         = 4
      min_count         = 1
      health_check_path = "/actuator/health"
      auto_scaling      = true
      secrets           = {
        "SPRING_DATA_MONGODB_URI" = "arn:aws:ssm:region:account:parameter/mongodb-uri"
      }
      environment       = {
        "SPRING_PROFILES_ACTIVE" = "docker"
      }
    },
    "inventory-service" = {
      container_port    = 8082
      host_port         = 0
      cpu               = 256
      memory            = 512
      desired_count     = 2
      max_count         = 4
      min_count         = 1
      health_check_path = "/actuator/health"
      auto_scaling      = true
      secrets           = {
        "SPRING_DATASOURCE_USERNAME" = "arn:aws:ssm:region:account:parameter/mysql-username",
        "SPRING_DATASOURCE_PASSWORD" = "arn:aws:ssm:region:account:parameter/mysql-password"
      }
      environment       = {
        "SPRING_PROFILES_ACTIVE" = "docker",
        "SPRING_DATASOURCE_URL"  = "jdbc:mysql://mysql.internal:3306/microservices"
      }
    },
    "order-service" = {
      container_port    = 8081
      host_port         = 0
      cpu               = 256
      memory            = 512
      desired_count     = 2
      max_count         = 4
      min_count         = 1
      health_check_path = "/actuator/health"
      auto_scaling      = true
      secrets           = {
        "SPRING_DATASOURCE_USERNAME" = "arn:aws:ssm:region:account:parameter/mysql-username",
        "SPRING_DATASOURCE_PASSWORD" = "arn:aws:ssm:region:account:parameter/mysql-password"
      }
      environment       = {
        "SPRING_PROFILES_ACTIVE" = "docker",
        "SPRING_DATASOURCE_URL"  = "jdbc:mysql://mysql.internal:3306/microservices"
      }
    },
    "notification-service" = {
      container_port    = 8083
      host_port         = 0
      cpu               = 256
      memory            = 512
      desired_count     = 2
      max_count         = 4
      min_count         = 1
      health_check_path = "/actuator/health"
      auto_scaling      = true
      secrets           = {}
      environment       = {
        "SPRING_PROFILES_ACTIVE"      = "docker",
        "SPRING_KAFKA_BOOTSTRAP-SERVERS" = "kafka.internal:9092"
      }
    }
  }
}

variable "ecr_repository_url" {
  description = "Base URL for ECR repositories"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

variable "app_mesh_enabled" {
  description = "Whether to enable AWS App Mesh for service mesh"
  type        = bool
  default     = false
}

variable "enable_container_insights" {
  description = "Whether to enable Container Insights for CloudWatch"
  type        = bool
  default     = true
}