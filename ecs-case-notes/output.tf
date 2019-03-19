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

# primary ec2
output "mongodb_instance_id" {
  value = "${module.create-ec2-instance.instance_id}"
}

output "mongodb_instance_private_ip" {
  value = "${module.create-ec2-instance.private_ip}"
}

# dns
output "mongodb_instance_dns" {
  value = "${aws_route53_record.mongodb.fqdn}"
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

# ELB
output "asg_elb_id" {
  description = "The name of the ELB"
  value       = "${module.create_app_elb.environment_elb_id}"
}

output "asg_elb_name" {
  description = "The name of the ELB"
  value       = "${module.create_app_elb.environment_elb_name}"
}

output "asg_elb_dns_name" {
  description = "The DNS name of the ELB"
  value       = "${module.create_app_elb.environment_elb_dns_name}"
}

output "asg_elb_source_security_group_id" {
  description = "The ID of the security group that you can use as part of your inbound rules for your load balancer's back-end application instances"
  value       = "${module.create_app_elb.environment_elb_source_security_group_id}"
}

output "asg_elb_zone_id" {
  description = "The canonical hosted zone ID of the ELB (to be used in a Route 53 Alias record)"
  value       = "${module.create_app_elb.environment_elb_zone_id}"
}

output "asg_elb_dns_cname" {
  value = "${aws_route53_record.dns_entry.fqdn}"
}

# ECS Service
output "ecs_service_id" {
  value = "${module.app_service.ecs_service_id}"
}

output "ecs_service_name" {
  value = "${module.app_service.ecs_service_name}"
}
