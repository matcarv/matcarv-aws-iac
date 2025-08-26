variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "matcarv"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "192.168.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3a.small"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.small"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "matcarvdb"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "admin"
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "app.matcarv.com.br"
}

variable "zone_name" {
  description = "Route53 zone name"
  type        = string
  default     = "matcarv.com.br"
}
