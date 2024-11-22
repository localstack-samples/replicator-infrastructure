variable "aws_profile" {
  description = "aws profile to deploy the platform"
}

variable "region" {
  type        = string
  description = "aws region to deploy the vpc"
  default     = "us-east-1"
}
