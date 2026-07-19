variable "aws_region" {
  description = "Region for all resources."
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Prefix applied to every resource name."
  type        = string
  default     = "zero-trust-test"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet hosting the EC2 client."
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type for the client."
  type        = string
  default     = "t3.micro"
}

variable "alarm_email" {
  description = "Email address for alarm notifications. Leave empty to skip the subscription."
  type        = string
  default     = ""
}
