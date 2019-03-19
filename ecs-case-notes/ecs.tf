#-------------------------------------------------------------
### Getting the latest centos ami
#-------------------------------------------------------------
data "aws_ami" "ecs_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["HMPPS ECS Centos master*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  owners = ["${data.terraform_remote_state.common.common_account_id}", "895523100917"] # MOJ
}

####################################################
# Locals
####################################################

locals {
  application           = "case-notes"
  image_url             = "${var.image_url}"
  app_port              = "8080"
  mongodb_root_user     = "${var.mongodb_root_user}"
  ecs_memory            = "2048"
  ecs_cpu_units         = "256"
  logs_bucket           = "${data.terraform_remote_state.common.common_s3_lb_logs_bucket}"
  service_desired_count = "${var.case-notes-service_desired_count}"
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

############################################
# CREATE ECS TASK DEFINTIONS
############################################

data "aws_ecs_task_definition" "app_task_definition" {
  task_definition = "${module.app_task_definition.task_definition_family}"
  depends_on      = ["module.app_task_definition"]
}

data "template_file" "app_task_definition" {
  template = "${file("../task_definitions/case-notes.conf")}"

  vars {
    environment            = "${local.environment}"
    app_port               = "${local.app_port}"
    image_url              = "${local.image_url}"
    container_name         = "${local.application}"
    log_group_name         = "${module.create_loggroup.loggroup_name}"
    log_group_region       = "${local.region}"
    memory                 = "${local.ecs_memory}"
    cpu_units              = "${local.ecs_cpu_units}"
    s3_bucket_config       = "${local.config-bucket}"
    mongodb_root_user      = "${local.mongodb_root_user}"
    root_user_password_arn = "${aws_ssm_parameter.param.arn}"
  }
}

module "app_task_definition" {
  source                = "git::https://github.com/ministryofjustice/hmpps-terraform-modules.git?ref=master//modules//ecs//ecs-taskdefinitions//app"
  app_name              = "${local.common_name}"
  container_name        = "${local.application}"
  container_definitions = "${data.template_file.app_task_definition.rendered}"
}

############################################
# CREATE ECS SERVICES
############################################

module "app_service" {
  source                          = "git::https://github.com/ministryofjustice/hmpps-terraform-modules.git?ref=master//modules//ecs/ecs_service//withloadbalancer//elb"
  servicename                     = "${local.common_name}"
  clustername                     = "${module.ecs_cluster.ecs_cluster_id}"
  ecs_service_role                = "${local.ecs_service_role}"
  containername                   = "${local.application}"
  containerport                   = "${local.app_port}"
  task_definition_family          = "${module.app_task_definition.task_definition_family}"
  task_definition_revision        = "${module.app_task_definition.task_definition_revision}"
  current_task_definition_version = "${data.aws_ecs_task_definition.app_task_definition.revision}"
  service_desired_count           = "${local.service_desired_count}"
  elb_name                        = "${module.create_app_elb.environment_elb_name}"
}
