# ECS
output "ecs_cluster_arn" {
  value = "${module.ecs_cluster.ecs_cluster_arn}"
}

output "ecs_cluster_id" {
  value = "${module.ecs_cluster.ecs_cluster_id}"
}

# LOG GROUPS
output "loggroup_arn" {
  value = "${module.create_loggroup.loggroup_arn}"
}

output "loggroup_name" {
  value = "${module.create_loggroup.loggroup_name}"
}

# Parameter store
output "mongodb_root_user" {
  value = "${local.mongodb_root_user}"
}

output "mongodb_root_user_password_parameter_arn" {
  value = "${aws_ssm_parameter.param.arn}"
}

output "mongodb_root_user_password_parameter_name" {
  value = "${aws_ssm_parameter.param.name}"
}

# Task definition
output "task_definition_arn" {
  value = "${module.app_task_definition.task_definition_arn}"
}

output "task_definition_family" {
  value = "${module.app_task_definition.task_definition_family}"
}

output "task_definition_revision" {
  value = "${module.app_task_definition.task_definition_revision}"
}
