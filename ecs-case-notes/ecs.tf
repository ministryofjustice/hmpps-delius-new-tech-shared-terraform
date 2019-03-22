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
  image_url             = "${var.case-notes-image_url}"
  app_port              = "8080"
  mongodb_root_user     = "${var.mongodb_root_user}"
  ecs_memory            = "2048"
  ecs_cpu_units         = "256"
  logs_bucket           = "${data.terraform_remote_state.common.common_s3_lb_logs_bucket}"
  service_desired_count = "${var.case-notes-service_desired_count}"
  push_base_url         = "${var.push_base_url}"
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
    environment      = "${local.environment}"
    app_port         = "${local.app_port}"
    image_url        = "${local.image_url}"
    container_name   = "${local.application}"
    log_group_name   = "${module.create_loggroup.loggroup_name}"
    log_group_region = "${local.region}"
    memory           = "${local.ecs_memory}"
    cpu_units        = "${local.ecs_cpu_units}"
    s3_bucket_config = "${local.config-bucket}"
    mongo_db_host    = "${aws_route53_record.mongodb.fqdn}"
    mongo_db_name    = "pollpush"
    push_base_url    = "${local.push_base_url}"
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
  source                          = "git::https://github.com/ministryofjustice/hmpps-terraform-modules.git?ref=issue-137//modules//ecs/ecs_service//noloadbalancer//elb"
  servicename                     = "${local.common_name}"
  clustername                     = "${module.ecs_cluster.ecs_cluster_id}"
  ecs_service_role                = "${local.ecs_service_role}"
  task_definition_family          = "${module.app_task_definition.task_definition_family}"
  task_definition_revision        = "${module.app_task_definition.task_definition_revision}"
  current_task_definition_version = "${data.aws_ecs_task_definition.app_task_definition.revision}"
  service_desired_count           = "${local.service_desired_count}"
}

#-------------------------------------------------------------
### Create ecs  
#-------------------------------------------------------------

data "template_file" "userdata_ecs" {
  template = "${file("../userdata/ecs.sh")}"

  vars {
    app_name             = "${local.app_name}"
    bastion_inventory    = "${local.bastion_inventory}"
    env_identifier       = "${local.environment_identifier}"
    short_env_identifier = "${local.short_environment_identifier}"
    route53_sub_domain   = "${local.environment}.${local.app_name}"
    container_name       = "${local.service}"
    private_domain       = "${local.internal_domain}"
    account_id           = "${local.account_id}"
    internal_domain      = "${local.internal_domain}"
    environment          = "${local.environment}"
    common_name          = "${local.common_name}"
    ecs_cluster          = "${module.ecs_cluster.ecs_cluster_name}"
  }
}

############################################
# CREATE LAUNCH CONFIG FOR EC2 RUNNING SERVICES
############################################

module "launch_cfg" {
  source                      = "git::https://github.com/ministryofjustice/hmpps-terraform-modules.git?ref=master//modules//launch_configuration//noblockdevice"
  launch_configuration_name   = "${local.common_name}"
  image_id                    = "${data.aws_ami.ecs_ami.id}"
  instance_type               = "t2.medium"
  volume_size                 = "30"
  instance_profile            = "${local.instance_profile}"
  key_name                    = "${local.ssh_deployer_key}"
  associate_public_ip_address = false
  security_groups             = ["${local.app_security_groups}"]
  user_data                   = "${data.template_file.userdata_ecs.rendered}"
}

# ############################################
# # CREATE AUTO SCALING GROUP
# ############################################

#AZ1
module "auto_scale_az1" {
  source               = "git::https://github.com/ministryofjustice/hmpps-terraform-modules.git?ref=pre-shared-vpc//modules//autoscaling//group//asg_classic_lb"
  asg_name             = "${local.common_name}-az1"
  subnet_ids           = ["${local.private_subnet_ids[0]}"]
  asg_min              = 1
  asg_max              = 1
  asg_desired          = 1
  launch_configuration = "${module.launch_cfg.launch_name}"
  load_balancers       = ["${module.create_app_elb.environment_elb_name}"]
  tags                 = "${local.tags}"
}
