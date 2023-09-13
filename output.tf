################################################################################
# Defines the list of output for the created infrastructure
################################################################################

output "ecs_cluster_arn" {
  value = module.ecs_cluster.arn
}

output "ecs_service_discovery_arn" {
  value = aws_service_discovery_http_namespace.ecs_service_discovery.arn
}

output "target_group_arn" {
  value = module.alb.target_group_arns
}

output "security_group_id" {
  value = module.alb.security_group_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "alb_dns_name" {
  value = module.alb.lb_dns_name
}
