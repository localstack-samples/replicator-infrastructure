terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "= 5.60.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "docker" {}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

