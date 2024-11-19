variable "aws_profile" {
  description = "aws profile to deploy the platform"
}

variable "region" {
  type        = string
  description = "aws region to deploy the vpc"
  default     = "us-east-1"
}

variable "vpc_id" {
  type        = string
  description = "Vpc id to deploy the application"
}

variable "private_subnets" {
  type        = list(string)
  description = "List of private subnets where to deploy the application"
}

variable "public_subnets" {
  type        = list(string)
  description = "List of public subnets where to deploy the application"
}
