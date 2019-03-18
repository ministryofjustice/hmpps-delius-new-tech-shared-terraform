####################################################
# Locals
####################################################

locals {
  application       = "case-notes"
  image_url         = "${var.image_url}"
  app_port          = "8080"
  mongodb_root_user = "${var.mongodb_root_user}"
  ecs_memory        = "2048"
  ecs_cpu_units     = "256"
}

############################################
# CREATE ECS CLUSTER
############################################

module "ecs_cluster" {
  source       = "git::https://github.com/ministryofjustice/hmpps-terraform-modules.git?ref=master//modules//ecs//ecs_cluster"
  cluster_name = "${local.common_name}"

  tags = "${local.tags}"
}

############################################
# CREATE LOG GROUPS FOR CONTAINER LOGS
############################################

module "create_loggroup" {
  source                   = "git::https://github.com/ministryofjustice/hmpps-terraform-modules.git?ref=master//modules//cloudwatch//loggroup"
  log_group_path           = "${local.common_name}"
  loggroupname             = "${local.application}"
  cloudwatch_log_retention = "${var.cloudwatch_log_retention}"
  tags                     = "${local.tags}"
}

###############################################
# MONGODB DB PASSWORD
###############################################
resource "random_string" "mongodb_password" {
  length  = 20
  special = true
}

# Add to SSM
resource "aws_ssm_parameter" "param" {
  name        = "${local.common_name}-${local.application}-root-user-password"
  description = "${local.common_name}-${local.application}-root-user-password"
  type        = "SecureString"
  value       = "${sha256(bcrypt(random_string.mongodb_password.result))}"

  tags = "${merge(local.tags, map("Name", "${local.common_name}-${local.application}-root-user-password"))}"

  lifecycle {
    ignore_changes = ["value"]
  }
}

############################################
# CREATE ECS TASK DEFINTIONS
############################################


# data "aws_ecs_task_definition" "app_task_definition" {
#   task_definition = "${module.app_task_definition.task_definition_family}"
#   depends_on      = ["module.app_task_definition"]
# }


# data "template_file" "app_task_definition" {
#   template = "${file("../task_definitions/mongodb.conf")}"


#   vars {
#     environment            = "${local.environment}"
#     app_port               = "${local.app_port}"
#     image_url              = "${local.image_url}"
#     container_name         = "${local.service}"
#     log_group_name         = "${module.create_loggroup.loggroup_name}"
#     log_group_region       = "${local.region}"
#     memory                 = "${local.ecs_memory}"
#     cpu_units              = "${local.ecs_cpu_units}"
#     s3_bucket_config       = "${local.config-bucket}"
#     mongodb_root_user      = "${local.mongodb_root_user}"
#     root_user_password_arn = "${aws_ssm_parameter.param.arn}"
#   }
# }


# module "app_task_definition" {
#   source                = "git::https://github.com/ministryofjustice/hmpps-terraform-modules.git?ref=master//modules//ecs//ecs-taskdefinitions//app"
#   app_name              = "${local.common_name}"
#   container_name        = "${local.application}"
#   container_definitions = "${data.template_file.app_task_definition.rendered}"
# }

