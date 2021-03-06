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
  availability_zone_map        = "${data.terraform_remote_state.common.availability_zone_map}"
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
  certificate_arn              = "${data.aws_acm_certificate.cert.arn}"
  public_subnet_ids            = ["${data.terraform_remote_state.common.public_subnet_ids}"]
  private_subnet_ids           = ["${data.terraform_remote_state.common.private_subnet_ids}"]
  db_subnet_ids                = ["${data.terraform_remote_state.common.db_subnet_ids}"]
  public_cidr_block            = ["${data.terraform_remote_state.common.db_cidr_block}"]
  config-bucket                = "${data.terraform_remote_state.common.common_s3-config-bucket}"
  ecs_service_role             = "${data.terraform_remote_state.iam.iam_role_int_ecs_role_arn}"
  instance_profile             = "${data.terraform_remote_state.iam.iam_case_notes_app_instance_profile_name}"
  sg_map_ids                   = "${data.terraform_remote_state.common.sg_map_ids}"
  bastion_inventory            = "${data.terraform_remote_state.common.bastion_inventory}"

  mongodb_security_groups = [
    "${data.terraform_remote_state.security-groups.security_groups_sg_case_notes_mongodb_db_in}",
    "${data.terraform_remote_state.common.common_sg_outbound_id}",
    "${data.terraform_remote_state.common.sg_map_ids["bastion_in_sg_id"]}",
  ]

  app_security_groups = [
    "${data.terraform_remote_state.security-groups.security_groups_sg_case_notes_api_in}",
    "${data.terraform_remote_state.common.common_sg_outbound_id}",
    "${data.terraform_remote_state.common.sg_map_ids["bastion_in_sg_id"]}",
  ]

  external_lb_security_groups = [
    "${data.terraform_remote_state.security-groups.security_groups_sg_case_notes_external_lb_in}",
  ]

  tags = "${data.terraform_remote_state.common.common_tags}"
}
