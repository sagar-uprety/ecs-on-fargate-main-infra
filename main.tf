################################################################################
# Defines the resources to be created
################################################################################

# CLUSTER

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "5.2.2"

  cluster_name = local.name

  create = true # Determines whether resources will be created (affects all resources)


  cluster_settings = {
    "name" : "containerInsights",
    "value" : "enabled"
  }

  cloudwatch_log_group_retention_in_days = 90
  create_cloudwatch_log_group            = true
  create_task_exec_iam_role              = false # Determines whether the ECS task definition IAM role should be created
  create_task_exec_policy                = true  # Create IAM policy for task execution (Uses Managed AmazonECSTaskExecutionRolePolicy)
  default_capacity_provider_use_fargate  = true  # Use Fargate as default capacity provider
  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/${local.name}"
      }
    }
  }

  cluster_service_connect_defaults = {
    namespace = aws_service_discovery_http_namespace.ecs_service_discovery.arn
  }

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
  }
}

################################################################################
# Supporting Resources
################################################################################

resource "aws_service_discovery_http_namespace" "ecs_service_discovery" {
  name        = local.name
  description = "CloudMap namespace for ${local.name}"
  tags        = local.tags
}


module "alb_sg" {
  source      = "terraform-aws-modules/security-group/aws"
  version     = "~> 5.0"
  name        = "${local.name}-service"
  description = "Service security group"
  vpc_id      = module.vpc.vpc_id

  ingress_rules       = ["http-80-tcp"] #"grafana-tcp"
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = module.vpc.private_subnets_cidr_blocks

}

#ALB

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"
  name    = local.name

  load_balancer_type = "application"

  vpc_id          = module.vpc.vpc_id
  subnets         = module.vpc.public_subnets
  security_groups = [module.alb_sg.security_group_id]
  http_tcp_listeners = [
    {
      port     = 80
      protocol = "HTTP"
    }
  ]

  http_tcp_listener_rules = [
    {
      http_tcp_listener_index = 0
      actions = [
        {
          type               = "forward"
          target_group_index = 0
        }
      ]

      conditions = [
        {
          path_patterns = ["/users*"]
        }
      ]
    },
    {
      http_tcp_listener_index = 0
      actions = [
        {
          type               = "forward"
          target_group_index = 1
        }
      ]

      conditions = [
        {
          path_patterns = ["/products*"]
        }
      ]
    },

    {
      http_tcp_listener_index = 0
      actions = [
        {
          type               = "forward"
          target_group_index = 2
        }
      ]

      conditions = [
        {
          path_patterns = ["/orders*"]
        }
      ]
    }
  ]

  target_groups = [
    {
      name             = "${local.name}-${local.containers[0].name}-alb-tg"
      backend_protocol = "HTTP"
      backend_port     = local.containers[0].port
      target_type      = "ip"
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/users"
        port                = local.containers[0].port
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
      }
    },
    {
      name             = "${local.name}-${local.containers[1].name}-alb-tg"
      backend_protocol = "HTTP"
      backend_port     = local.containers[1].port
      target_type      = "ip"
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/products"
        port                = local.containers[1].port
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
      }
    },
    {
      name             = "${local.name}-${local.containers[2].name}-alb-tg"
      backend_protocol = "HTTP"
      backend_port     = local.containers[2].port
      target_type      = "ip"
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/orders"
        port                = local.containers[2].port
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
      }
    }
  ]

}


# VPC

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"
  name    = "lms-dev"
  cidr    = local.vpc_cidr

  azs             = local.azs
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true # Should be true if you want to provision NAT Gateways for each of your private networks

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}


# DynamoDB

module "order_dynamodb_table" {
  source   = "terraform-aws-modules/dynamodb-table/aws"
  version  = "3.3.0"
  name     = "ecs-orders-ms"
  hash_key = "id"

  attributes = [
    {
      name = "id"
      type = "S"
    }
  ]

}

module "user_dynamodb_table" {
  source   = "terraform-aws-modules/dynamodb-table/aws"
  version  = "3.3.0"
  name     = "ecs-users-ms"
  hash_key = "id"

  attributes = [
    {
      name = "id"
      type = "S"
    }
  ]

}

module "product_dynamodb_table" {
  source   = "terraform-aws-modules/dynamodb-table/aws"
  version  = "3.3.0"
  name     = "ecs-products-ms"
  hash_key = "id"

  attributes = [
    {
      name = "id"
      type = "S"
    }
  ]

}


# ECR
module "order_ecr" {
  source                  = "terraform-aws-modules/ecr/aws"
  version                 = "1.6.0"
  repository_name         = "lms-order-ms"
  repository_force_delete = true
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 10 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 10
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

}

module "user_ecr" {
  source                  = "terraform-aws-modules/ecr/aws"
  version                 = "1.6.0"
  repository_name         = "lms-user-ms"
  repository_force_delete = true
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 10 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 10
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

}


module "product_ecr" {
  source                  = "terraform-aws-modules/ecr/aws"
  version                 = "1.6.0"
  repository_name         = "lms-product-ms"
  repository_force_delete = true
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 10 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 10
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

}
