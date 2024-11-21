terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 5.60.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

