variable "environment" {
  description = "The environment (dev, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block of the VPC"
  type        = string
}

variable "public_subnets_cidr" {
  description = "The CIDR blocks for the public subnets"
  type        = list(string)
}

variable "private_subnets_cidr" {
  description = "The CIDR blocks for the private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "The availability zones to use"
  type        = list(string)
}