################################################################################
# Defines the local variables
################################################################################

data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

locals {
  name    = "lms-ecs-fargate"
  project = "ecs-module-lms"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)

  containers = [
    {
      name = "user",
      port = 3000,
    },
    {
      name = "product",
      port = 3001,
    },
    {
      name = "order",
      port = 3002
    },
  ]

  tags = {
    Name    = local.name,
    Project = local.project
  }
}
