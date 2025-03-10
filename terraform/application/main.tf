locals {
  name           = "ecs-application"
  container_name = "application"
  container_port = 3000
  host_port      = 80

  image_path = "${path.module}/../../image"
  image_sha  = sha1(join("", [for f in fileset(local.image_path, ".*") : filesha1(f)]))
}


################################################################################
# ECR Repository
################################################################################

# Create an ECR repository
resource "aws_ecr_repository" "app_ecr_repo" {
  name         = "application-repo"
  force_delete = true
}

resource "docker_image" "application_image" {
  name = "application"
  build {
    context = local.image_path
  }

  triggers = {
    dir_sha1 = local.image_sha
  }

}

resource "docker_tag" "application_latest" {
  source_image = docker_image.application_image.name
  target_image = aws_ecr_repository.app_ecr_repo.repository_url
}

resource "terraform_data" "docker-push" {
  provisioner "local-exec" {
    command = "docker push ${docker_tag.application_latest.target_image}"
  }

  depends_on = [docker_tag.application_latest]
  triggers_replace = {
    dir_sha1 = local.image_path
  }
}

################################################################################
# ECS Cluster
################################################################################

module "ecs_cluster" {
  source = "terraform-aws-modules/ecs/aws"

  cluster_name = local.name

  # Capacity provider
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
      }
    }
  }

  services = {
    application-services = {
      cpu    = 512
      memory = 1024

      # Container definition(s)
      container_definitions = {
        (local.container_name) = {
          cpu       = 512
          memory    = 1024
          essential = true
          image     = "000000000000.dkr.ecr.us-east-1.localhost.localstack.cloud:4566/application-repo:latest"
          port_mappings = [
            {
              name          = local.container_name
              containerPort = local.container_port
              hostPort      = local.host_port
              protocol      = "tcp"
              app_protocol  = "http"
            }
          ]
        }
      }

      # Load Balancer Attachment
      load_balancer = {
        service = {
          target_group_arn = module.alb.target_groups["ex_ecs"].arn
          container_name   = local.container_name
          container_port   = local.container_port
        }
      }

      # Network & Security
      subnet_ids = var.private_subnets
      security_group_rules = {
        alb_ingress_80 = {
          type                     = "ingress"
          from_port                = local.container_port
          to_port                  = local.container_port
          protocol                 = "tcp"
          description              = "Service port"
          source_security_group_id = module.alb.security_group_id
        }
        egress_all = {
          type        = "egress"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
    }
  }
  depends_on = [docker_tag.application_latest, terraform_data.docker-push]
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "= 9.10.0"

  name = local.name

  load_balancer_type = "application"
  internal           = true

  vpc_id  = var.vpc_id
  subnets = var.private_subnets

  # For example only
  enable_deletion_protection = false

  # Security Group
  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  listeners = {
    ex_http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "ex_ecs"
      }
    }
  }

  target_groups = {
    ex_ecs = {
      backend_protocol = "HTTP"
      backend_port     = local.container_port
      target_type      = "ip"

      health_check = {
        enabled             = true
        healthy_threshold   = 5
        interval            = 30
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }

      # There's nothing to attach here in this definition. Instead,
      # ECS will attach the IPs of the tasks to this target group
      create_attachment = false
    }
  }
}


module "api_gateway_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = local.name
  description = "API Gateway group for ALB Invoke"
  vpc_id      = var.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["all-all"]

  egress_rules = ["all-all"]
}

module "api_gateway" {
  source = "terraform-aws-modules/apigateway-v2/aws"

  # API
  name = local.name

  # Custom Domain
  create_domain_name = false

  # Routes & Integration(s)
  routes = {
    "ANY /{proxy+}" = {
      integration = {
        connection_type = "VPC_LINK"
        uri             = module.alb.listeners["ex_http"].arn
        type            = "HTTP_PROXY"
        method          = "ANY"
        vpc_link_key    = "my-vpc"
      }
    }
  }

  # VPC Link
  vpc_links = {
    my-vpc = {
      name               = local.name
      security_group_ids = [module.api_gateway_security_group.security_group_id]
      subnet_ids         = var.private_subnets
    }
  }
}
