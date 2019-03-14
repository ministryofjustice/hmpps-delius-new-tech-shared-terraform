# ECS
output "ecs_cluster_arn" {
  value = "${module.ecs_cluster.ecs_cluster_arn}"
}

output "ecs_cluster_id" {
  value = "${module.ecs_cluster.ecs_cluster_id}"
}
