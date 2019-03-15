terraform {
  # The configuration for this backend will be filled in by Terragrunt
  backend "s3" {}
}

provider "aws" {
  region  = "${var.region}"
  version = "~> 1.16"
}

####################################################
# DATA SOURCE MODULES FROM OTHER TERRAFORM BACKENDS
####################################################
#-------------------------------------------------------------
### Getting the common details
#-------------------------------------------------------------
data "terraform_remote_state" "common" {
  backend = "s3"

  config {
    bucket = "${var.remote_state_bucket_name}"
    key    = "new-tech/common/terraform.tfstate"
    region = "${var.region}"
  }
}

#-------------------------------------------------------------
### Getting the IAM details
#-------------------------------------------------------------
data "terraform_remote_state" "iam" {
  backend = "s3"

  config {
    bucket = "${var.remote_state_bucket_name}"
    key    = "new-tech/iam/terraform.tfstate"
    region = "${var.region}"
  }
}

#-------------------------------------------------------------
### Getting the security groups details
#-------------------------------------------------------------
data "terraform_remote_state" "security-groups" {
  backend = "s3"

  config {
    bucket = "${var.remote_state_bucket_name}"
    key    = "new-tech/security-groups/terraform.tfstate"
    region = "${var.region}"
  }
}

#-------------------------------------------------------------
### Getting ACM Cert
#-------------------------------------------------------------
data "aws_acm_certificate" "cert" {
  domain      = "*.${data.terraform_remote_state.common.external_domain}"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

#-------------------------------------------------------------
### Getting the latest amazon ami
#-------------------------------------------------------------
data "aws_ami" "amazon_ami" {
  most_recent = true

  filter {
    name   = "description"
    values = ["Amazon Linux AMI *"]
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

  owners = ["591542846629"] # AWS
}

####################################################
# Locals
####################################################

locals {
  ami_id                       = "${data.aws_ami.amazon_ami.id}"
  account_id                   = "${data.terraform_remote_state.common.common_account_id}"
  vpc_id                       = "${data.terraform_remote_state.common.vpc_id}"
  cidr_block                   = "${data.terraform_remote_state.common.vpc_cidr_block}"
  internal_domain              = "${data.terraform_remote_state.common.internal_domain}"
  private_zone_id              = "${data.terraform_remote_state.common.private_zone_id}"
  external_domain              = "${data.terraform_remote_state.common.external_domain}"
  public_zone_id               = "${data.terraform_remote_state.common.public_zone_id}"
  environment_identifier       = "${data.terraform_remote_state.common.environment_identifier}"
  short_environment_identifier = "${data.terraform_remote_state.common.short_environment_identifier}"
  common_name                  = "${data.terraform_remote_state.common.common_name}-case-notes"
  region                       = "${var.region}"
  app_name                     = "${data.terraform_remote_state.common.app_name}"
  environment                  = "${data.terraform_remote_state.common.environment}"
  ssh_deployer_key             = "${data.terraform_remote_state.common.common_ssh_deployer_key}"
  app_hostnames                = "${data.terraform_remote_state.common.app_hostnames}"
  certificate_arn              = ["${data.aws_acm_certificate.cert.arn}"]
  public_subnet_ids            = ["${data.terraform_remote_state.common.public_subnet_ids}"]
  private_subnet_ids           = ["${data.terraform_remote_state.common.private_subnet_ids}"]
  public_cidr_block            = ["${data.terraform_remote_state.common.db_cidr_block}"]
  config-bucket                = "${data.terraform_remote_state.common.common_s3-config-bucket}"
  ecs_service_role             = "${data.terraform_remote_state.iam.iam_role_int_ecs_role_arn}"
  service_desired_count        = "1"
  instance_profile             = "${data.terraform_remote_state.iam.iam_case_notes_app_instance_profile_name}"
  sg_map_ids                   = "${data.terraform_remote_state.common.sg_map_ids}"

  instance_security_groups = [
    "${data.terraform_remote_state.security-groups.security_groups_sg_case_notes_mongodb_db_in}",
    "${data.terraform_remote_state.common.common_sg_outbound_id}",
  ]

  tags              = "${data.terraform_remote_state.common.common_tags}"
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

data "aws_ecs_task_definition" "app_task_definition" {
  task_definition = "${module.app_task_definition.task_definition_family}"
  depends_on      = ["module.app_task_definition"]
}

data "template_file" "app_task_definition" {
  template = "${file("../task_definitions/mongodb.conf")}"

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
